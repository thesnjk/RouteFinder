package com.routefinder.fleetdriver.fleet

import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import org.json.JSONObject
import java.util.concurrent.TimeUnit

/**
 * UK DVLA Vehicle Enquiry Service (VES) client.
 * Mirrors iOS ``DVLAVehicleEnquiryEngine`` / ``DVLAVehicleResponse``.
 * Operator-supplied ``x-api-key`` — fills revenue weight / HGV class, not full H×W×L CAD.
 */
class DvlaVehicleEnquiryClient(
    private val apiKey: String,
    private val client: OkHttpClient = OkHttpClient.Builder()
        .connectTimeout(4, TimeUnit.SECONDS)
        .readTimeout(6, TimeUnit.SECONDS)
        .build(),
) {
    data class Spec(
        val make: String?,
        val weightTonnes: Double?,
        val isHeavyGoodsVehicle: Boolean,
        /** Default artic envelope when VES marks HGV (matches iOS registry profile defaults). */
        val heightMeters: Double?,
        val widthMeters: Double?,
        val lengthMeters: Double?,
    )

    fun lookup(registration: String): Spec? {
        val key = apiKey.trim()
        if (key.isEmpty()) return null
        val plate = normalizeRegistration(registration)
        if (plate.isEmpty()) return null
        val body = JSONObject().put("registrationNumber", plate).toString()
        val request = Request.Builder()
            .url(ENDPOINT)
            .post(body.toRequestBody(JSON_MEDIA))
            .header("x-api-key", key)
            .header("Content-Type", "application/json")
            .header("User-Agent", "RouteFinderAndroid/1.0")
            .build()
        client.newCall(request).execute().use { response ->
            when (response.code) {
                200 -> {
                    val text = response.body?.string().orEmpty()
                    return parseBody(text)
                }
                404, 401, 403 -> return null
                else -> return null
            }
        }
    }

    companion object {
        const val ENDPOINT = "https://driver-vehicle-licensing.api.gov.uk/v1/vehicles"
        private val JSON_MEDIA = "application/json; charset=utf-8".toMediaType()

        fun normalizeRegistration(raw: String): String =
            raw.replace("\\s+".toRegex(), "").uppercase()

        /** Parses VES JSON into a Spec (safe for fixtures — no network). */
        fun parseBody(json: String): Spec? {
            return try {
                val root = JSONObject(json)
                val revenueWeight = if (root.has("revenueWeight") && !root.isNull("revenueWeight")) {
                    root.optInt("revenueWeight", 0).takeIf { it > 0 }
                } else {
                    null
                }
                val make = root.optString("make").takeIf { it.isNotBlank() }
                val typeApproval = root.optString("typeApproval")
                val wheelplan = root.optString("wheelplan")
                val artics = root.optString("artics")
                val fuelType = root.optString("fuelType")
                val isHgv = isHeavyGoodsVehicle(
                    revenueWeightKg = revenueWeight,
                    typeApproval = typeApproval,
                    wheelplan = wheelplan,
                    artics = artics,
                    fuelType = fuelType,
                )
                val weightTonnes = revenueWeight?.let { it / 1000.0 }?.takeIf { it > 0 }
                if (isHgv) {
                    Spec(
                        make = make,
                        weightTonnes = weightTonnes ?: 44.0,
                        isHeavyGoodsVehicle = true,
                        heightMeters = 4.0,
                        widthMeters = 2.55,
                        lengthMeters = 16.5,
                    )
                } else {
                    Spec(
                        make = make,
                        weightTonnes = weightTonnes,
                        isHeavyGoodsVehicle = false,
                        heightMeters = null,
                        widthMeters = null,
                        lengthMeters = null,
                    )
                }
            } catch (_: Exception) {
                null
            }
        }

        fun isHeavyGoodsVehicle(
            revenueWeightKg: Int?,
            typeApproval: String?,
            wheelplan: String?,
            artics: String?,
            fuelType: String?,
        ): Boolean {
            if (revenueWeightKg != null && revenueWeightKg >= 3500) return true
            val combined = listOfNotNull(typeApproval, wheelplan, artics, fuelType)
                .joinToString(" ")
                .lowercase()
            return combined.contains("artic") ||
                combined.contains("hgv") ||
                combined.contains("goods") ||
                combined.contains("truck") ||
                combined.contains("lorry")
        }
    }
}
