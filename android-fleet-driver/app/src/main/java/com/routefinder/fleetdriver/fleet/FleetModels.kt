package com.routefinder.fleetdriver.fleet

import com.routefinder.fleetdriver.routing.HgvVehicleProfile
import org.json.JSONArray
import org.json.JSONObject

data class FleetTripStop(
    val id: String,
    val sequence: Int,
    val label: String,
    val latitude: Double,
    val longitude: Double,
    val role: String,
)

/** Optional per-stop arrival window from dispatch (ISO-8601 instants). */
data class StopTimeWindow(
    val stopId: String,
    val earliestArrival: String? = null,
    val latestArrival: String? = null,
)

/** Optional dispatch job brief (weight / ADR / time windows / auto-intake flags). */
data class FleetJobBrief(
    val grossWeightKg: Double? = null,
    val adrClass: String? = null,
    val timeWindows: List<StopTimeWindow> = emptyList(),
    val autoFindRoute: Boolean = true,
    val autoRehearse: Boolean = false,
)

/** Optional vehicle dimensions echoed from the fleet server (metres / tonnes). */
data class FleetVehicleProfile(
    val height: Double? = null,
    val weight: Double? = null,
    val width: Double? = null,
    val length: Double? = null,
    val axleWeight: Double? = null,
)

data class FleetTrip(
    val id: String,
    val orgId: String,
    val vehicleId: String,
    val status: String,
    val stops: List<FleetTripStop>,
    val physicsETASeconds: Double?,
    val updatedAt: String,
    val jobBrief: FleetJobBrief? = null,
    val vehicleProfile: FleetVehicleProfile? = null,
)

data class FleetDispatchEvent(
    val kind: String,
    val vehicleId: String,
    val tripId: String?,
    val timestamp: String,
)

data class FleetVehicle(
    val id: String,
    val orgId: String,
    val label: String,
    val registrationPlate: String?,
    val profile: FleetVehicleProfile?,
)

/** Fleet snapshot media budgets (parity with iOS InspectionMediaBudget). */
object InspectionMediaBudget {
    /** Max base64 PDF characters on a fleet trip snapshot. */
    const val maxPDFBase64Characters = 900_000

    /** Truncates a PDF base64 payload for fleet upload when over budget. */
    fun cappedPDFBase64(base64: String): String? {
        if (base64.isEmpty()) return null
        return if (base64.length <= maxPDFBase64Characters) {
            base64
        } else {
            base64.take(maxPDFBase64Characters)
        }
    }
}

fun FleetTrip.toSnapshotJson(
    statusOverride: String? = null,
    driverLatitude: Double? = null,
    driverLongitude: Double? = null,
    driverLocationRecordedAt: String? = null,
    physicsETASecondsOverride: Double? = null,
    latestInspectionSummary: JSONObject? = null,
    inspectionReportPDFBase64: String? = null,
): JSONObject {
    val ordered = JSONArray()
    stops.sortedBy { it.sequence }.forEach { ordered.put(it.id) }
    val physics = physicsETASecondsOverride ?: physicsETASeconds
    val json = JSONObject()
        .put("tripId", id)
        .put("status", statusOverride ?: status)
        .put("orderedStopIds", ordered)
        .put("physicsETASeconds", physics ?: JSONObject.NULL)
        .put("updatedAt", updatedAt)
    if (driverLatitude != null) json.put("driverLatitude", driverLatitude)
    if (driverLongitude != null) json.put("driverLongitude", driverLongitude)
    if (driverLocationRecordedAt != null) json.put("driverLocationRecordedAt", driverLocationRecordedAt)
    if (latestInspectionSummary != null) json.put("latestInspectionSummary", latestInspectionSummary)
    val cappedPdf = inspectionReportPDFBase64?.let { InspectionMediaBudget.cappedPDFBase64(it) }
    if (cappedPdf != null) json.put("inspectionReportPDFBase64", cappedPdf)
    return json
}

fun parseVehicle(json: JSONObject): FleetVehicle =
    FleetVehicle(
        id = json.getString("id"),
        orgId = json.getString("orgId"),
        label = json.getString("label"),
        registrationPlate = if (json.has("registrationPlate") && !json.isNull("registrationPlate")) {
            json.getString("registrationPlate")
        } else {
            null
        },
        profile = parseVehicleProfile(json.optJSONObject("profile")),
    )

fun parseJobBrief(json: JSONObject?): FleetJobBrief? {
    if (json == null) return null
    val adr = if (json.has("adrClass") && !json.isNull("adrClass")) {
        json.getString("adrClass").takeIf { it.isNotBlank() }
    } else {
        null
    }
    return FleetJobBrief(
        grossWeightKg = if (json.isNull("grossWeightKg")) null else json.optDouble("grossWeightKg"),
        adrClass = adr,
        timeWindows = parseTimeWindows(json.optJSONArray("timeWindows")),
        autoFindRoute = json.optBoolean("autoFindRoute", true),
        autoRehearse = json.optBoolean("autoRehearse", false),
    )
}

fun parseTimeWindows(array: JSONArray?): List<StopTimeWindow> {
    if (array == null) return emptyList()
    return buildList {
        for (i in 0 until array.length()) {
            val w = array.optJSONObject(i) ?: continue
            val stopId = w.optString("stopId").takeIf { it.isNotBlank() } ?: continue
            add(
                StopTimeWindow(
                    stopId = stopId,
                    earliestArrival = if (w.has("earliestArrival") && !w.isNull("earliestArrival")) {
                        w.getString("earliestArrival")
                    } else {
                        null
                    },
                    latestArrival = if (w.has("latestArrival") && !w.isNull("latestArrival")) {
                        w.getString("latestArrival")
                    } else {
                        null
                    },
                ),
            )
        }
    }
}

/** Formats dispatch time windows for the driver status card. */
fun formatTimeWindowLines(trip: FleetTrip): List<String> {
    val windows = trip.jobBrief?.timeWindows.orEmpty()
    if (windows.isEmpty()) return emptyList()
    val stopsById = trip.stops.associateBy { it.id }
    return windows.map { window ->
        val label = stopsById[window.stopId]?.label ?: "Stop ${window.stopId.take(8)}"
        val earliest = window.earliestArrival?.let { shortenIso(it) }
        val latest = window.latestArrival?.let { shortenIso(it) }
        when {
            earliest != null && latest != null -> "$label: $earliest – $latest"
            earliest != null -> "$label: after $earliest"
            latest != null -> "$label: before $latest"
            else -> "$label: window unset"
        }
    }
}

private fun shortenIso(raw: String): String {
    // Prefer "YYYY-MM-DD HH:MM" over full ISO when present.
    val trimmed = raw.trim()
    return when {
        trimmed.length >= 16 && trimmed[10] == 'T' ->
            trimmed.substring(0, 16).replace('T', ' ')
        else -> trimmed
    }
}

fun parseVehicleProfile(json: JSONObject?): FleetVehicleProfile? {
    if (json == null) return null
    return FleetVehicleProfile(
        height = if (json.isNull("height")) null else json.optDouble("height"),
        weight = if (json.isNull("weight")) null else json.optDouble("weight"),
        width = if (json.isNull("width")) null else json.optDouble("width"),
        length = if (json.isNull("length")) null else json.optDouble("length"),
        axleWeight = if (json.isNull("axleWeight")) null else json.optDouble("axleWeight"),
    )
}

/**
 * Builds an ORS HGV profile from trip vehicle dimensions + job brief weight/ADR.
 * ADR class maps to ORS `hazmat: true` (mirrors iOS OpenRouteServicePayloadBuilder).
 */
fun FleetTrip.toHgvVehicleProfile(): HgvVehicleProfile {
    val base = vehicleProfile
    val brief = jobBrief
    val weightTonnes = when {
        brief?.grossWeightKg != null && brief.grossWeightKg > 0 -> brief.grossWeightKg / 1000.0
        base?.weight != null && base.weight > 0 -> base.weight
        else -> 40.0
    }
    val hazmat = hazmatEnabled(fromADR = brief?.adrClass)
    return HgvVehicleProfile(
        lengthMeters = base?.length ?: 16.5,
        widthMeters = base?.width ?: 2.55,
        heightMeters = base?.height ?: 4.0,
        weightTonnes = weightTonnes,
        axleLoadTonnes = base?.axleWeight ?: 11.5,
        hazmat = hazmat,
    )
}

/** True when desk ADR class implies a hazmat load (any non-blank / non-none class). */
fun hazmatEnabled(fromADR: String?): Boolean {
    val trimmed = fromADR?.trim()?.lowercase().orEmpty()
    if (trimmed.isEmpty() || trimmed == "none" || trimmed == "0") return false
    return true
}

fun parseTrip(json: JSONObject): FleetTrip {
    val stopsJson = json.optJSONArray("stops") ?: JSONArray()
    val stops = buildList {
        for (i in 0 until stopsJson.length()) {
            val s = stopsJson.getJSONObject(i)
            add(
                FleetTripStop(
                    id = s.getString("id"),
                    sequence = s.getInt("sequence"),
                    label = s.getString("label"),
                    latitude = s.getDouble("latitude"),
                    longitude = s.getDouble("longitude"),
                    role = s.getString("role"),
                ),
            )
        }
    }
    return FleetTrip(
        id = json.getString("id"),
        orgId = json.getString("orgId"),
        vehicleId = json.getString("vehicleId"),
        status = json.getString("status"),
        stops = stops,
        physicsETASeconds = if (json.isNull("physicsETASeconds")) null else json.getDouble("physicsETASeconds"),
        updatedAt = json.optString("updatedAt", ""),
        jobBrief = parseJobBrief(json.optJSONObject("jobBrief")),
        vehicleProfile = parseVehicleProfile(json.optJSONObject("vehicleProfile")),
    )
}

fun parseEvent(json: JSONObject): FleetDispatchEvent =
    FleetDispatchEvent(
        kind = json.getString("kind"),
        vehicleId = json.getString("vehicleId"),
        tripId = if (json.has("tripId") && !json.isNull("tripId")) json.getString("tripId") else null,
        timestamp = json.optString("timestamp", ""),
    )
