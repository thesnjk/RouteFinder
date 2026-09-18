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
