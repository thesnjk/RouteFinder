package com.routefinder.fleetdriver.compliance

import org.json.JSONObject
import java.io.File
import java.time.Instant

/**
 * Best-effort importer for driver-card DDD files and JSON remaining-time fixtures.
 *
 * Real DDD is a complex binary format. This importer:
 * - Parses the simple JSON schema and text dumps with known keys
 * - Accepts a companion `.json` sidecar next to a binary `.ddd`
 * - Throws [TachoImportError.UnrecognizedBinaryDDD] for opaque binaries
 *
 * Mirrors iOS ``DDDImporter``.
 */
class DddImporter(
    private val now: () -> Instant = { Instant.now() },
) {
    /** Parses driver-card payload bytes (JSON fixture / text dump preferred). */
    fun importDriverCard(
        data: ByteArray,
        sourceFileName: String = "import",
        sidecarData: ByteArray? = null,
    ): TachoCardSummary {
        runCatching { parseJSONExport(data, sourceFileName) }.getOrNull()?.let { return it }
        runCatching { parseTextDump(data, sourceFileName) }.getOrNull()?.let { return it }
        if (sidecarData != null) {
            runCatching { parseJSONExport(sidecarData, sourceFileName) }.getOrNull()?.let { return it }
        }
        if (looksLikeBinary(data)) {
            throw TachoImportError.UnrecognizedBinaryDDD
        }
        jsonFailure(data)
    }

    /** Loads a file, preferring a sibling `.json` sidecar when the primary file is binary DDD. */
    fun importDriverCard(file: File): TachoCardSummary {
        val data = file.readBytes()
        val sidecar = sidecarJSONFile(file)?.takeIf { it.exists() }?.readBytes()
        return importDriverCard(
            data = data,
            sourceFileName = file.name,
            sidecarData = sidecar,
        )
    }

    private fun parseJSONExport(data: ByteArray, sourceFileName: String): TachoCardSummary {
        val text = data.toString(Charsets.UTF_8)
        val dict = try {
            JSONObject(text)
        } catch (_: Exception) {
            throw TachoImportError.InvalidJSON
        }
        return summaryFrom(dict, sourceFileName)
    }

    private fun parseTextDump(data: ByteArray, sourceFileName: String): TachoCardSummary {
        val text = data.toString(Charsets.UTF_8).ifBlank {
            data.toString(Charsets.ISO_8859_1)
        }.trim()
        if (text.isEmpty() || text.startsWith("{")) {
            throw TachoImportError.InvalidJSON
        }
        val values = mutableMapOf<String, Any>()
        for (line in text.lineSequence()) {
            val parts = line.split(":", limit = 2).map { it.trim() }
            if (parts.size != 2) continue
            val key = parts[0]
            val raw = parts[1]
            val asNumber = raw.toDoubleOrNull()
            if (asNumber != null) {
                values[key] = asNumber
            } else if (raw.isNotEmpty()) {
                values[key] = raw
            }
        }
        return summaryFromMap(values, sourceFileName)
    }

    private fun summaryFrom(dict: JSONObject, sourceFileName: String): TachoCardSummary {
        val map = mutableMapOf<String, Any>()
        val keys = dict.keys()
        while (keys.hasNext()) {
            val k = keys.next()
            map[k] = dict.get(k)
        }
        return summaryFromMap(map, sourceFileName)
    }

    private fun summaryFromMap(dict: Map<String, Any>, sourceFileName: String): TachoCardSummary {
        val continuous = number(
            dict,
            listOf(
                "remainingContinuousDriveSeconds",
                "remainingDriveSeconds",
                "continuousDriveRemainingSeconds",
            ),
        )
        val daily = number(
            dict,
            listOf(
                "remainingDailyDriveSeconds",
                "dailyDriveRemainingSeconds",
            ),
        )
        val weekly = number(
            dict,
            listOf(
                "remainingWeeklyDriveSeconds",
                "weeklyDriveRemainingSeconds",
            ),
        ) ?: continuous?.let { WEEKLY_DRIVE_LIMIT_SECONDS }

        if (continuous == null || daily == null || weekly == null) {
            throw TachoImportError.MissingRequiredFields
        }

        val cardNumber = string(
            dict,
            listOf("cardNumber", "driverCardNumber", "card_number"),
        )

        return TachoCardSummary(
            remainingContinuousDriveSeconds = continuous,
            remainingDailyDriveSeconds = daily,
            remainingWeeklyDriveSeconds = weekly,
            cardNumber = cardNumber,
            importedAt = now(),
            sourceFileName = sourceFileName,
        )
    }

    private fun jsonFailure(data: ByteArray): Nothing {
        try {
            JSONObject(data.toString(Charsets.UTF_8))
            throw TachoImportError.MissingRequiredFields
        } catch (e: TachoImportError) {
            throw e
        } catch (_: Exception) {
            throw TachoImportError.InvalidJSON
        }
    }

    private fun looksLikeBinary(data: ByteArray): Boolean {
        if (data.isEmpty()) return false
        val asUtf8 = runCatching { data.toString(Charsets.UTF_8) }.getOrNull()
        if (asUtf8 != null) {
            val first = data.firstOrNull()?.toInt()?.toChar()
            if (first == '{' || first == '[') return false
            val sample = data.take(256)
            val nonPrintable = sample.count { byte ->
                val b = byte.toInt() and 0xFF
                b !in 0x09..0x0D && b !in 0x20..0x7E
            }
            return nonPrintable.toDouble() / maxOf(sample.size, 1).toDouble() > 0.2
        }
        return true
    }

    companion object {
        /** EU 561 weekly drive limit (seconds) — mirrors iOS ``EU561HosClock.weeklyDriveLimitSeconds``. */
        const val WEEKLY_DRIVE_LIMIT_SECONDS = 56.0 * 3_600

        fun sidecarJSONFile(primary: File): File? {
            val sibling = File(primary.parentFile, primary.nameWithoutExtension + ".json")
            return if (sibling != primary && sibling.exists()) sibling else null
        }

        private fun number(dict: Map<String, Any>, keys: List<String>): Double? {
            for (key in keys) {
                val value = dict[key] ?: continue
                when (value) {
                    is Number -> return value.toDouble()
                    is String -> value.toDoubleOrNull()?.let { return it }
                }
            }
            return null
        }

        private fun string(dict: Map<String, Any>, keys: List<String>): String? {
            for (key in keys) {
                val value = dict[key] as? String ?: continue
                val trimmed = value.trim()
                if (trimmed.isNotEmpty()) return trimmed
            }
            return null
        }
    }
}
