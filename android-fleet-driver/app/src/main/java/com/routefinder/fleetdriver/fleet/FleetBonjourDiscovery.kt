package com.routefinder.fleetdriver.fleet

import android.content.Context
import android.net.nsd.NsdManager
import android.net.nsd.NsdServiceInfo
import android.os.Build
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.coroutines.withContext
import kotlinx.coroutines.withTimeoutOrNull
import kotlin.coroutines.resume

/** A fleet server discovered via Bonjour / NSD on the local network. */
data class DiscoveredFleetServer(
    val displayName: String,
    val baseUrl: String,
)

/**
 * Discovers RouteFinderFleetServer instances advertised as `_routefinder-fleet._tcp`
 * (matches iOS [FleetBonjour] / [FleetBonjourBrowser]).
 */
object FleetBonjourDiscovery {
    const val SERVICE_TYPE = "_routefinder-fleet._tcp."
    const val TXT_TLS_KEY = "tls"
    const val DEFAULT_TIMEOUT_MS = 3_000L

    /**
     * Builds a fleet server base URL from resolved host metadata.
     * IPv6 hosts are bracketed; invalid ports return null.
     */
    fun baseUrl(host: String, port: Int, usesTls: Boolean): String? {
        val trimmed = host.trim()
        if (trimmed.isEmpty() || port <= 0 || port > 65_535) return null
        val scheme = if (usesTls) "https" else "http"
        val hostPart =
            if (trimmed.contains(":") && !trimmed.startsWith("[")) {
                "[$trimmed]"
            } else {
                trimmed
            }
        return "$scheme://$hostPart:$port"
    }

    /** Returns whether a TXT attribute map indicates TLS (`tls=1`). */
    fun usesTls(attributes: Map<String, ByteArray>?): Boolean {
        val raw = attributes?.get(TXT_TLS_KEY) ?: return false
        return String(raw, Charsets.UTF_8) == "1"
    }

    /**
     * Scans the LAN for fleet servers for up to [timeoutMs].
     * Requires multicast (same Wi‑Fi as the Mac running RouteFinderFleetServer).
     */
    suspend fun discover(
        context: Context,
        timeoutMs: Long = DEFAULT_TIMEOUT_MS,
    ): List<DiscoveredFleetServer> = withContext(Dispatchers.Main) {
        val nsd = context.applicationContext.getSystemService(Context.NSD_SERVICE) as NsdManager
        val found = mutableListOf<NsdServiceInfo>()
        val lock = Any()

        val discoveryListener = object : NsdManager.DiscoveryListener {
            override fun onDiscoveryStarted(serviceType: String) {}
            override fun onDiscoveryStopped(serviceType: String) {}
            override fun onStartDiscoveryFailed(serviceType: String, errorCode: Int) {}
            override fun onStopDiscoveryFailed(serviceType: String, errorCode: Int) {}
            override fun onServiceLost(serviceInfo: NsdServiceInfo) {}
            override fun onServiceFound(serviceInfo: NsdServiceInfo) {
                if (serviceInfo.serviceType.contains("routefinder-fleet")) {
                    synchronized(lock) { found.add(serviceInfo) }
                }
            }
        }

        try {
            nsd.discoverServices(SERVICE_TYPE, NsdManager.PROTOCOL_DNS_SD, discoveryListener)
            delay(timeoutMs)
        } finally {
            runCatching { nsd.stopServiceDiscovery(discoveryListener) }
        }

        val snapshots = synchronized(lock) { found.toList() }
        val servers = mutableListOf<DiscoveredFleetServer>()
        for (info in snapshots) {
            val resolved = resolveService(nsd, info) ?: continue
            val host = hostFrom(resolved) ?: continue
            val port = resolved.port
            val tls = usesTls(txtAttributes(resolved))
            val url = baseUrl(host, port, tls) ?: continue
            servers.add(
                DiscoveredFleetServer(
                    displayName = resolved.serviceName.ifBlank { "RouteFinder Fleet" },
                    baseUrl = url,
                ),
            )
        }
        servers
            .distinctBy { it.baseUrl }
            .sortedBy { it.displayName.lowercase() }
    }

    private suspend fun resolveService(
        nsd: NsdManager,
        info: NsdServiceInfo,
    ): NsdServiceInfo? = withTimeoutOrNull(2_000L) {
        suspendCancellableCoroutine { cont ->
            val listener = object : NsdManager.ResolveListener {
                override fun onResolveFailed(serviceInfo: NsdServiceInfo, errorCode: Int) {
                    if (cont.isActive) cont.resume(null)
                }

                override fun onServiceResolved(serviceInfo: NsdServiceInfo) {
                    if (cont.isActive) cont.resume(serviceInfo)
                }
            }
            nsd.resolveService(info, listener)
        }
    }

    private fun hostFrom(info: NsdServiceInfo): String? {
        val host = info.host ?: return null
        return host.hostAddress ?: host.hostName
    }

    private fun txtAttributes(info: NsdServiceInfo): Map<String, ByteArray>? {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
            @Suppress("DEPRECATION")
            val attrs = info.attributes
            if (attrs != null && attrs.isNotEmpty()) return attrs
        }
        return null
    }
}
