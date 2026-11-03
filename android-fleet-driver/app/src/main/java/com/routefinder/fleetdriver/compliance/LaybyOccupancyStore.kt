package com.routefinder.fleetdriver.compliance

import android.content.SharedPreferences
import org.json.JSONObject
import java.time.Instant

/**
 * Persists latest on-device occupancy taps per layby site.
 * Fresh taps (within [FRESHNESS_HOURS]) override the hour-of-day prior.
 */
class LaybyOccupancyStore(
    private val backend: Backend,
) {
    interface Backend {
        fun getJson(): String?
        fun setJson(value: String)
    }

    class PrefsBackend(
        private val prefs: SharedPreferences,
        private val key: String = KEY_DEFAULT,
    ) : Backend {
        override fun getJson(): String? = prefs.getString(key, null)
        override fun setJson(value: String) {
            prefs.edit().putString(key, value).apply()
        }
    }

    /** In-memory backend for unit tests (no Robolectric). */
    class MemoryBackend : Backend {
        private var raw: String? = null
        override fun getJson(): String? = raw
        override fun setJson(value: String) {
            raw = value
        }
    }

    data class Tap(
        val kind: LaybyOccupancyKind,
        val recordedAt: Instant,
    )

    constructor(prefs: SharedPreferences, key: String = KEY_DEFAULT) : this(PrefsBackend(prefs, key))

    fun latest(siteId: String, now: Instant = Instant.now()): Tap? {
        val all = loadAll()
        val raw = all.optJSONObject(siteId) ?: return null
        val kindRaw = raw.optString("kind", "")
        val kind = when (kindRaw) {
            "full" -> LaybyOccupancyKind.FULL
            "spaces" -> LaybyOccupancyKind.SPACES_AVAILABLE
            else -> return null
        }
        val at = runCatching { Instant.parse(raw.optString("at", "")) }.getOrNull() ?: return null
        val ageHours = (now.epochSecond - at.epochSecond) / 3600.0
        if (ageHours > FRESHNESS_HOURS) return null
        return Tap(kind = kind, recordedAt = at)
    }

    fun record(siteId: String, kind: LaybyOccupancyKind, at: Instant = Instant.now()) {
        val all = loadAll()
        all.put(
            siteId,
            JSONObject()
                .put("kind", if (kind == LaybyOccupancyKind.FULL) "full" else "spaces")
                .put("at", at.toString()),
        )
        backend.setJson(all.toString())
    }

    /** Resolves availability tier: fresh tap wins, else hour-of-day prior. */
    fun resolveTier(
        siteId: String,
        hour: Int,
        now: Instant = Instant.now(),
    ): ParkingAvailabilityTier {
        val tap = latest(siteId, now)
        if (tap != null) {
            return when (tap.kind) {
                LaybyOccupancyKind.FULL -> ParkingAvailabilityTier.FULL
                LaybyOccupancyKind.SPACES_AVAILABLE -> ParkingAvailabilityTier.AMPLE
            }
        }
        return ParkingAvailabilityTier.fromOccupancyPrior(LaybyOccupancyPrior.forHour(hour))
    }

    private fun loadAll(): JSONObject {
        val raw = backend.getJson().orEmpty()
        if (raw.isBlank()) return JSONObject()
        return runCatching { JSONObject(raw) }.getOrElse { JSONObject() }
    }

    companion object {
        const val FRESHNESS_HOURS = 6.0
        private const val KEY_DEFAULT = "layby_occupancy_taps_v1"

        fun inMemory(): LaybyOccupancyStore = LaybyOccupancyStore(MemoryBackend())
    }
}
