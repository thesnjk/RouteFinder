package com.routefinder.fleetdriver.fleet

import android.content.Context
import android.content.SharedPreferences

/** Persists fleet pairing and C2 navigation preferences. */
class FleetPreferences(context: Context) {
    private val prefs: SharedPreferences =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    var baseUrl: String
        get() = prefs.getString(KEY_BASE, DEFAULT_BASE) ?: DEFAULT_BASE
        set(value) = prefs.edit().putString(KEY_BASE, value.trim()).apply()

    var apiKey: String
        get() = prefs.getString(KEY_API, "") ?: ""
        set(value) = prefs.edit().putString(KEY_API, value.trim()).apply()

    var vehicleId: String
        get() = prefs.getString(KEY_VEHICLE, "") ?: ""
        set(value) = prefs.edit().putString(KEY_VEHICLE, value.trim()).apply()

    var setupComplete: Boolean
        get() = prefs.getBoolean(KEY_SETUP_DONE, false)
        set(value) = prefs.edit().putBoolean(KEY_SETUP_DONE, value).apply()

    var onboardingSeen: Boolean
        get() = prefs.getBoolean(KEY_ONBOARDING, false)
        set(value) = prefs.edit().putBoolean(KEY_ONBOARDING, value).apply()

    var driverTermsAccepted: Boolean
        get() = prefs.getBoolean(KEY_TERMS, false)
        set(value) = prefs.edit().putBoolean(KEY_TERMS, value).apply()

    var voiceGuidanceEnabled: Boolean
        get() = prefs.getBoolean(KEY_VOICE, true)
        set(value) = prefs.edit().putBoolean(KEY_VOICE, value).apply()

    /** Optional RegCheck username for plate → dims on job intake. */
    var regCheckUsername: String
        get() = prefs.getString(KEY_REGCHECK, "") ?: ""
        set(value) = prefs.edit().putString(KEY_REGCHECK, value.trim()).apply()

    /** Optional TomTom API key for 1–3h forecast traffic samples. */
    var tomTomApiKey: String
        get() = prefs.getString(KEY_TOMTOM, "") ?: ""
        set(value) = prefs.edit().putString(KEY_TOMTOM, value.trim()).apply()

    /** Optional OpenWeather API key for horizon weather advisories. */
    var openWeatherApiKey: String
        get() = prefs.getString(KEY_OPENWEATHER, "") ?: ""
        set(value) = prefs.edit().putString(KEY_OPENWEATHER, value.trim()).apply()

    /** When true, Overpass clearance radar runs after route find (default on). */
    var clearanceRadarEnabled: Boolean
        get() = prefs.getBoolean(KEY_CLEARANCE, true)
        set(value) = prefs.edit().putBoolean(KEY_CLEARANCE, value).apply()

    /** When true, advisory LEZ/CAZ avoidance is enabled (default on). */
    var lezAvoidEnabled: Boolean
        get() = prefs.getBoolean(KEY_LEZ, true)
        set(value) = prefs.edit().putBoolean(KEY_LEZ, value).apply()

    /** Euro emission class label (`EURO6`, `EURO5`, …). */
    var emissionClass: String
        get() = prefs.getString(KEY_EMISSION, "EURO6") ?: "EURO6"
        set(value) = prefs.edit().putString(KEY_EMISSION, value.trim()).apply()

    var continuousDriveSeconds: Double
        get() = java.lang.Double.longBitsToDouble(prefs.getLong(KEY_HOS_CONT, 0L))
        set(value) = prefs.edit().putLong(KEY_HOS_CONT, java.lang.Double.doubleToRawLongBits(value)).apply()

    var dailyDriveSeconds: Double
        get() = java.lang.Double.longBitsToDouble(prefs.getLong(KEY_HOS_DAILY, 0L))
        set(value) = prefs.edit().putLong(KEY_HOS_DAILY, java.lang.Double.doubleToRawLongBits(value)).apply()

    /** `lan` or `hosted` — UX preference for wizard copy. */
    var connectionKind: String
        get() {
            val stored = prefs.getString(KEY_CONN_KIND, null)
            if (stored != null) return stored
            return if (baseUrl.trim().lowercase().startsWith("https://")) "hosted" else "lan"
        }
        set(value) = prefs.edit().putString(KEY_CONN_KIND, value).apply()

    val isHosted: Boolean get() = connectionKind == "hosted"

    fun isPaired(): Boolean = vehicleId.isNotBlank() && baseUrl.isNotBlank()

    companion object {
        const val PREFS = "fleet_driver"
        const val KEY_BASE = "base_url"
        const val KEY_API = "api_key"
        const val KEY_VEHICLE = "vehicle_id"
        const val KEY_SETUP_DONE = "setup_complete"
        const val KEY_ONBOARDING = "onboarding_seen"
        const val KEY_TERMS = "driver_terms_accepted"
        const val KEY_VOICE = "voice_guidance_enabled"
        const val KEY_REGCHECK = "regcheck_username"
        const val KEY_TOMTOM = "tomtom_api_key"
        const val KEY_OPENWEATHER = "openweather_api_key"
        const val KEY_CLEARANCE = "clearance_radar_enabled"
        const val KEY_LEZ = "lez_avoid_enabled"
        const val KEY_EMISSION = "emission_class"
        const val KEY_HOS_CONT = "hos_continuous_drive_seconds"
        const val KEY_HOS_DAILY = "hos_daily_drive_seconds"
        const val KEY_CONN_KIND = "connection_kind"
        const val DEFAULT_BASE = "http://10.0.2.2:8080"
        const val VEHICLE_QR_PREFIX = "routefinder-vehicle:"
    }
}

/** Parses pasted or scanned vehicle QR payloads into a UUID string. */
object VehicleQRParser {
    fun parse(raw: String): String? {
        val trimmed = raw.trim()
        if (trimmed.isEmpty()) return null
        val uuidPart = if (trimmed.lowercase().startsWith(FleetPreferences.VEHICLE_QR_PREFIX)) {
            trimmed.substring(FleetPreferences.VEHICLE_QR_PREFIX.length).trim()
        } else {
            trimmed
        }
        return if (UUID_REGEX.matches(uuidPart)) uuidPart else null
    }

    private val UUID_REGEX =
        Regex("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$")
}
