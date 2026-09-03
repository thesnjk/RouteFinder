package com.routefinder.fleetdriver.fleet

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.flow
import kotlinx.coroutines.flow.flowOn
import okhttp3.OkHttpClient
import org.json.JSONObject
import java.io.BufferedReader
import java.io.InputStreamReader
import java.util.concurrent.TimeUnit

/**
 * SSE client for `GET /v1/vehicles/{id}/events`.
 * Expects `data: {json}` lines matching FleetDispatchEvent.
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
}
