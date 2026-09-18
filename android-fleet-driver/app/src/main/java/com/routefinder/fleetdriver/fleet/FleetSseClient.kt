package com.routefinder.fleetdriver.fleet

import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.flow
import kotlinx.coroutines.flow.flowOn
import kotlinx.coroutines.Dispatchers
import okhttp3.OkHttpClient
import org.json.JSONObject
import java.io.BufferedReader
import java.io.InputStreamReader
import java.util.concurrent.TimeUnit

/** UI-facing SSE connection lifecycle. */
sealed class SseConnectionState {
    data object Listening : SseConnectionState()
    data class Reconnecting(val delaySeconds: Long) : SseConnectionState()
    data class Stopped(val reason: String?) : SseConnectionState()
}

/**
 * SSE client for `GET /v1/vehicles/{id}/events`.
 * Expects `data: {json}` lines matching FleetDispatchEvent.
 *
 * [events] is a single-shot stream (ends when the connection drops).
 * Prefer [eventsWithReconnect] for the home screen.
 */
class FleetSseClient(
    private val api: FleetApi,
    private val client: OkHttpClient = OkHttpClient.Builder()
        .readTimeout(0, TimeUnit.MILLISECONDS)
        .build(),
) {
    fun events(vehicleId: String): Flow<FleetDispatchEvent> = flow {
        val request = api.authorizedRequest(api.eventsUrl(vehicleId))
        client.newCall(request).execute().use { response ->
            if (!response.isSuccessful) {
                error("SSE ${response.code}")
            }
            val stream = response.body?.byteStream() ?: error("SSE empty body")
            BufferedReader(InputStreamReader(stream)).use { reader ->
                while (true) {
                    val line = reader.readLine() ?: break
                    if (!line.startsWith("data:")) continue
                    val payload = line.removePrefix("data:").trim()
                    if (payload.isEmpty()) continue
                    emit(parseEvent(JSONObject(payload)))
                }
            }
        }
    }.flowOn(Dispatchers.IO)

    /**
     * Resilient SSE with exponential backoff (2s → 4s → 8s, cap 30s).
     * Emits [SseConnectionState] updates and trip events via [onEvent] / [onState].
     */
    fun eventsWithReconnect(
        vehicleId: String,
        onState: (SseConnectionState) -> Unit,
    ): Flow<FleetDispatchEvent> = flow {
        var backoffMs = 2_000L
        while (true) {
            try {
                onState(SseConnectionState.Listening)
                events(vehicleId).collect { event ->
                    backoffMs = 2_000L
                    emit(event)
                }
                // Clean EOF — reconnect with backoff.
                val waitSec = backoffMs / 1000
                onState(SseConnectionState.Reconnecting(waitSec))
                delay(backoffMs)
                backoffMs = (backoffMs * 2).coerceAtMost(30_000L)
            } catch (_: Exception) {
                val waitSec = backoffMs / 1000
                onState(SseConnectionState.Reconnecting(waitSec))
                delay(backoffMs)
                backoffMs = (backoffMs * 2).coerceAtMost(30_000L)
            }
        }
    }.flowOn(Dispatchers.IO)
}
