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
    /**
     * Maps to a card-like summary for Can-I-drive evaluation.
     * Omitted weekly defaults to a full EU weekly planning allowance so partners
     * that only send continuous/daily do not falsely exhaust the week.
     */
    fun asCardSummary(): TachoCardSummary {
        val label = provider?.takeIf { it.isNotBlank() } ?: "partner"
        return TachoCardSummary(
            remainingContinuousDriveSeconds = remainingContinuousDriveSeconds,
            remainingDailyDriveSeconds = remainingDailyDriveSeconds,
            remainingWeeklyDriveSeconds = remainingWeeklyDriveSeconds ?: (56.0 * 3_600),
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
) {
    /** Serializes for on-device persistence of the last imported card. */
    fun toJson(): JSONObject =
        JSONObject().apply {
            put("remainingContinuousDriveSeconds", remainingContinuousDriveSeconds)
            put("remainingDailyDriveSeconds", remainingDailyDriveSeconds)
            put("remainingWeeklyDriveSeconds", remainingWeeklyDriveSeconds)
            if (cardNumber != null) put("cardNumber", cardNumber) else put("cardNumber", JSONObject.NULL)
            put("importedAt", importedAt.toString())
            put("sourceFileName", sourceFileName)
        }

    companion object {
        /** Restores a summary previously written by [toJson]. */
        fun fromJson(json: JSONObject): TachoCardSummary {
            val importedRaw = json.optString("importedAt", "")
            val importedAt = runCatching { Instant.parse(importedRaw) }.getOrElse { Instant.now() }
            return TachoCardSummary(
                remainingContinuousDriveSeconds = json.getDouble("remainingContinuousDriveSeconds"),
                remainingDailyDriveSeconds = json.getDouble("remainingDailyDriveSeconds"),
                remainingWeeklyDriveSeconds = json.optDouble("remainingWeeklyDriveSeconds", 0.0),
                cardNumber = json.optString("cardNumber").takeIf { it.isNotBlank() },
                importedAt = importedAt,
                sourceFileName = json.optString("sourceFileName", "import"),
            )
        }
    }
}
