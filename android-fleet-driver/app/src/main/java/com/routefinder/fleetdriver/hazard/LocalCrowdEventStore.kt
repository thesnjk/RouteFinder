package com.routefinder.fleetdriver.hazard

import org.json.JSONArray
import org.json.JSONObject
import java.io.File

/**
 * Disk-backed on-device crowd report store (iOS `LocalCrowdEventIngest` parity).
 * Retention window: 24 hours; promote window is enforced by [HazardAheadFormatter].
 */
class LocalCrowdEventStore(
    private val storageFile: File,
) {
    companion object {
        const val MAX_AGE_MS: Long = 24L * 3600L * 1000L
    }

    private val lock = Any()
    private var reports: MutableMap<String, CrowdReport> = LinkedHashMap()

    init {
        load()
    }

    fun submit(report: CrowdReport) {
        synchronized(lock) {
            reports[report.id] = report
            persistLocked()
        }
    }

    fun allReports(nowEpochMs: Long = System.currentTimeMillis()): List<CrowdReport> {
        synchronized(lock) {
            pruneLocked(nowEpochMs)
            return reports.values.sortedByDescending { it.createdAtEpochMs }
        }
    }

    private fun pruneLocked(nowEpochMs: Long) {
        val cutoff = nowEpochMs - MAX_AGE_MS
        val stale = reports.values.filter { it.createdAtEpochMs < cutoff }.map { it.id }
        if (stale.isEmpty()) return
        stale.forEach { reports.remove(it) }
        persistLocked()
    }

    private fun persistLocked() {
        storageFile.parentFile?.mkdirs()
        val array = JSONArray()
        for (report in reports.values) {
            array.put(
                JSONObject()
                    .put("id", report.id)
                    .put("latitude", report.latitude)
                    .put("longitude", report.longitude)
                    .put("type", report.type.name)
                    .put("reporterId", report.reporterId)
                    .put("createdAtEpochMs", report.createdAtEpochMs)
                    .put("note", report.note),
            )
        }
        storageFile.writeText(array.toString())
    }

    private fun load() {
        if (!storageFile.exists()) return
        runCatching {
            val array = JSONArray(storageFile.readText())
            val cutoff = System.currentTimeMillis() - MAX_AGE_MS
            val loaded = LinkedHashMap<String, CrowdReport>()
            for (i in 0 until array.length()) {
                val obj = array.getJSONObject(i)
                val created = obj.getLong("createdAtEpochMs")
                if (created < cutoff) continue
                val type = runCatching {
                    HazardEventType.valueOf(obj.getString("type"))
                }.getOrNull() ?: continue
                val report = CrowdReport(
                    id = obj.getString("id"),
                    latitude = obj.getDouble("latitude"),
                    longitude = obj.getDouble("longitude"),
                    type = type,
                    reporterId = obj.getString("reporterId"),
                    createdAtEpochMs = created,
                    note = if (obj.isNull("note")) {
                        null
                    } else {
                        obj.optString("note").takeIf { it.isNotBlank() }
                    },
                )
                loaded[report.id] = report
            }
            reports = loaded
        }
    }
}
