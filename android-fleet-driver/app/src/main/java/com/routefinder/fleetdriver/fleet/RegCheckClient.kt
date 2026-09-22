package com.routefinder.fleetdriver.fleet

import okhttp3.OkHttpClient
import okhttp3.Request
import org.json.JSONObject
import java.net.URLEncoder
import java.util.concurrent.TimeUnit
import java.util.regex.Pattern

/** UK RegCheck plate lookup (SOAP/XML) — mirrors iOS RegCheckRegistryProvider subset. */
class RegCheckClient(
    private val username: String,
    private val client: OkHttpClient = OkHttpClient.Builder()
        .connectTimeout(4, TimeUnit.SECONDS)
        .readTimeout(6, TimeUnit.SECONDS)
        .build(),
) {
    data class Spec(
        val heightMeters: Double?,
        val weightTonnes: Double?,
        val widthMeters: Double?,
        val lengthMeters: Double?,
    )

    fun lookup(registration: String): Spec? {
        val plate = registration.replace("\\s+".toRegex(), "").uppercase()
        if (plate.isEmpty() || username.isBlank()) return null
        val encodedPlate = URLEncoder.encode(plate, Charsets.UTF_8.name())
        val encodedUser = URLEncoder.encode(username.trim(), Charsets.UTF_8.name())
        val url =
            "https://www.regcheck.org.uk/api/reg.asmx/Check?RegistrationNumber=$encodedPlate&username=$encodedUser"
        val request = Request.Builder().url(url).get().build()
        client.newCall(request).execute().use { response ->
            if (!response.isSuccessful) return null
            val body = response.body?.string().orEmpty()
            return parseBody(body)
        }
    }

    companion object {
        fun parseBody(body: String): Spec? {
            // Prefer embedded vehicleJson when present.
            val jsonMatch = Pattern.compile(
                "vehicleJson[^>]*>\\s*(\\{.*?\\})\\s*<",
                Pattern.DOTALL or Pattern.CASE_INSENSITIVE,
            ).matcher(body)
            if (jsonMatch.find()) {
                return parseJsonVehicle(jsonMatch.group(1))
            }
            val height = captureField("Height", body) ?: captureField("VehicleHeight", body)
            val weight = captureField("GrossWeight", body) ?: captureField("GrossVehicleWeight", body)
            val width = captureField("Width", body)
            val length = captureField("Length", body)
            return Spec(
                heightMeters = parseMeters(height),
                weightTonnes = parseWeightTonnes(weight),
                widthMeters = parseMeters(width),
                lengthMeters = parseMeters(length),
            )
        }

        fun parseJsonVehicle(raw: String): Spec? {
            return try {
                val json = JSONObject(raw)
                Spec(
                    heightMeters = parseMeters(json.optString("Height", null)),
                    weightTonnes = parseWeightTonnes(
                        json.optString("GrossWeight", null)
                            ?: json.optString("GrossVehicleWeight", null),
                    ),
                    widthMeters = parseMeters(json.optString("Width", null)),
                    lengthMeters = parseMeters(json.optString("Length", null)),
                )
            } catch (_: Exception) {
                null
            }
        }

        fun captureField(name: String, text: String): String? {
            val pattern = Pattern.compile(
                "<$name[^>]*>\\s*([^<]+)\\s*</$name>",
                Pattern.CASE_INSENSITIVE,
            )
            val matcher = pattern.matcher(text)
            return if (matcher.find()) matcher.group(1)?.trim()?.takeIf { it.isNotEmpty() } else null
        }

        fun parseMeters(raw: String?): Double? {
            if (raw.isNullOrBlank()) return null
            val cleaned = raw.lowercase().replace("m", "").trim()
            return cleaned.toDoubleOrNull()?.takeIf { it > 0 && it < 20 }
        }

        fun parseWeightTonnes(raw: String?): Double? {
            if (raw.isNullOrBlank()) return null
            val lower = raw.lowercase().trim()
            if (lower.contains("kg")) {
                val kg = lower.replace("kg", "").trim().toDoubleOrNull() ?: return null
                return (kg / 1000.0).takeIf { it > 0 }
            }
            val tonnes = lower.replace("t", "").trim().toDoubleOrNull() ?: return null
            // RegCheck often returns kilograms as bare numbers > 1000.
            return if (tonnes > 200) tonnes / 1000.0 else tonnes
        }
    }
}

/** True when trip lacks usable dimensions and RegCheck should run. */
fun needsRegistrationLookup(trip: FleetTrip): Boolean {
    val profile = trip.vehicleProfile
    val hasDims = profile != null &&
        ((profile.height != null && profile.height > 0) || (profile.weight != null && profile.weight > 0))
    return !hasDims
}
