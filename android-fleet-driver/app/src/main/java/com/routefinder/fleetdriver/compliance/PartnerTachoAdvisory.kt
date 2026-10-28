package com.routefinder.fleetdriver.compliance

import org.json.JSONObject
import java.time.Instant

/**
 * Partner remaining-drive advisory from fleet `GET /v1/tacho/advisory`.
 * Planning aid only — not a legal VU record. Mirrors iOS ``PartnerTachoAdvisory``.
 */
data class PartnerTachoAdvisory(
    val remainingContinuousDriveSeconds: Double,
    val remainingDailyDriveSeconds: Double,
    val remainingWeeklyDriveSeconds: Double? = null,
    val recordedAt: Instant = Instant.now(),
    val provider: String? = null,
    val vehicleLabel: String? = null,
) {
    /** Maps to a card-like summary for Can-I-drive evaluation. */
    fun asCardSummary(): TachoCardSummary {
        val label = provider?.takeIf { it.isNotBlank() } ?: "partner"
        return TachoCardSummary(
            remainingContinuousDriveSeconds = remainingContinuousDriveSeconds,
            remainingDailyDriveSeconds = remainingDailyDriveSeconds,
            remainingWeeklyDriveSeconds = remainingWeeklyDriveSeconds ?: 0.0,
            cardNumber = vehicleLabel,
            importedAt = recordedAt,
            sourceFileName = "partner-webhook ($label)",
        )
    }

    companion object {
        fun fromJson(json: JSONObject): PartnerTachoAdvisory {
            val recordedRaw = json.optString("recordedAt", "")
            val recordedAt = runCatching { Instant.parse(recordedRaw) }.getOrElse { Instant.now() }
            return PartnerTachoAdvisory(
                remainingContinuousDriveSeconds = json.getDouble("remainingContinuousDriveSeconds"),
                remainingDailyDriveSeconds = json.getDouble("remainingDailyDriveSeconds"),
                remainingWeeklyDriveSeconds =
                    if (!json.has("remainingWeeklyDriveSeconds") ||
                        json.isNull("remainingWeeklyDriveSeconds")
                    ) {
                        null
                    } else {
                        json.getDouble("remainingWeeklyDriveSeconds")
                    },
                recordedAt = recordedAt,
                provider = json.optString("provider").takeIf { it.isNotBlank() },
                vehicleLabel = json.optString("vehicleLabel").takeIf { it.isNotBlank() },
            )
        }
    }
}

/** Lightweight remaining-drive summary used by ``CanIDriveEvaluator``. */
data class TachoCardSummary(
    val remainingContinuousDriveSeconds: Double,
    val remainingDailyDriveSeconds: Double,
    val remainingWeeklyDriveSeconds: Double = 0.0,
    val cardNumber: String? = null,
    val importedAt: Instant = Instant.now(),
    val sourceFileName: String,
)
