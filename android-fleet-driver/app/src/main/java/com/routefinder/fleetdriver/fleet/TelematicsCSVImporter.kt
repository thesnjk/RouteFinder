package com.routefinder.fleetdriver.fleet

import java.time.Instant
import java.time.format.DateTimeParseException
import java.util.Locale
import java.util.UUID

/** Telematics provider for read-only CSV / ingest stubs. */
enum class TelematicsProvider(val raw: String) {
    GEOTAB("geotab"),
    SAMSARA("samsara"),
    UNKNOWN("unknown"),
}

/** A single read-only vehicle position from a partner export. */
data class TelematicsVehiclePing(
    val provider: TelematicsProvider,
    val vehicleLabel: String,
    val latitude: Double,
    val longitude: Double,
    val recordedAt: Instant,
    val speedKph: Double? = null,
) {
    /** Deterministic UUID for fleet ingest when the CSV has no vehicle UUID. */
    fun ingestVehicleId(): UUID =
        UUID.nameUUIDFromBytes(vehicleLabel.trim().lowercase(Locale.US).toByteArray(Charsets.UTF_8))
}

/** Parsed CSV batch ready for local display / fleet upload. */
data class TelematicsImportBatch(
    val pings: List<TelematicsVehiclePing>,
    val sourceFileName: String? = null,
    val importedAt: Instant = Instant.now(),
)

/** Errors from telematics CSV import. */
sealed class TelematicsCSVImporterError(message: String) : Exception(message) {
    class EmptyFile : TelematicsCSVImporterError("Telematics CSV is empty.")
    class MissingRequiredColumns :
        TelematicsCSVImporterError("CSV needs latitude, longitude, and a vehicle/device column.")

    class NoValidRows : TelematicsCSVImporterError("No valid telematics rows found in CSV.")
}

/**
 * Tolerant CSV importer for Geotab / Samsara-style vehicle position exports (read-only).
 * Mirrors iOS ``TelematicsCSVImporter``.
 */
object TelematicsCSVImporter {
    fun parse(
        csv: String,
        defaultProvider: TelematicsProvider = TelematicsProvider.UNKNOWN,
    ): List<TelematicsVehiclePing> {
        val lines = csv.lineSequence()
            .map { it.trim() }
            .filter { it.isNotEmpty() }
            .toList()
        if (lines.isEmpty()) throw TelematicsCSVImporterError.EmptyFile()

        val headers = splitCSVLine(lines.first()).map { normalizeHeader(it) }
        val latIndex = indexOf(headers, listOf("latitude", "lat", "y"))
            ?: throw TelematicsCSVImporterError.MissingRequiredColumns()
        val lonIndex = indexOf(headers, listOf("longitude", "lon", "lng", "long", "x"))
            ?: throw TelematicsCSVImporterError.MissingRequiredColumns()
        val labelIndex = indexOf(
            headers,
            listOf("vehicle", "vehicle name", "device", "device name", "name", "asset", "unit"),
        ) ?: throw TelematicsCSVImporterError.MissingRequiredColumns()
        val timeIndex = indexOf(
            headers,
            listOf("datetime", "timestamp", "date", "time", "recordedat", "gps time", "date/time"),
        )
        val speedIndex = indexOf(headers, listOf("speed", "speedkph", "speed_kmh", "speedkmh"))
        val providerIndex = indexOf(headers, listOf("provider", "source", "telematics"))

        val pings = mutableListOf<TelematicsVehiclePing>()
        for (line in lines.drop(1)) {
            val cols = splitCSVLine(line)
            if (latIndex >= cols.size || lonIndex >= cols.size || labelIndex >= cols.size) continue
            val lat = cols[latIndex].trim().toDoubleOrNull() ?: continue
            val lon = cols[lonIndex].trim().toDoubleOrNull() ?: continue
            val label = cols[labelIndex].trim()
            if (label.isEmpty()) continue

            var recordedAt = Instant.now()
            if (timeIndex != null && timeIndex < cols.size) {
                parseInstant(cols[timeIndex].trim())?.let { recordedAt = it }
            }

            var speed: Double? = null
            if (speedIndex != null && speedIndex < cols.size) {
                speed = cols[speedIndex].trim().toDoubleOrNull()
            }

            var provider = defaultProvider
            if (providerIndex != null && providerIndex < cols.size) {
                val raw = cols[providerIndex].trim().lowercase(Locale.US)
                provider = when {
                    raw.contains("geotab") -> TelematicsProvider.GEOTAB
                    raw.contains("samsara") -> TelematicsProvider.SAMSARA
                    else -> provider
                }
            }

            pings += TelematicsVehiclePing(
                provider = provider,
                vehicleLabel = label,
                latitude = lat,
                longitude = lon,
                recordedAt = recordedAt,
                speedKph = speed,
            )
        }
        if (pings.isEmpty()) throw TelematicsCSVImporterError.NoValidRows()
        return pings
    }

    fun parseBatch(
        text: String,
        sourceFileName: String? = null,
        defaultProvider: TelematicsProvider = TelematicsProvider.UNKNOWN,
    ): TelematicsImportBatch =
        TelematicsImportBatch(
            pings = parse(text, defaultProvider),
            sourceFileName = sourceFileName,
        )

    private fun normalizeHeader(raw: String): String =
        raw.trim().trim('"').lowercase(Locale.US)

    private fun indexOf(headers: List<String>, aliases: List<String>): Int? {
        for ((i, header) in headers.withIndex()) {
            if (aliases.contains(header)) return i
        }
        return null
    }

    private fun parseInstant(raw: String): Instant? {
        if (raw.isEmpty()) return null
        return try {
            Instant.parse(raw)
        } catch (_: DateTimeParseException) {
            try {
                // Tolerate missing fractional seconds already handled by Instant.parse;
                // try stripping space separators.
                Instant.parse(raw.replace(' ', 'T'))
            } catch (_: DateTimeParseException) {
                null
            }
        }
    }

    private fun splitCSVLine(line: String): List<String> {
        val fields = mutableListOf<String>()
        val current = StringBuilder()
        var inQuotes = false
        for (char in line) {
            when {
                char == '"' -> inQuotes = !inQuotes
                char == ',' && !inQuotes -> {
                    fields += current.toString()
                    current.clear()
                }
                else -> current.append(char)
            }
        }
        fields += current.toString()
        return fields
    }
}
