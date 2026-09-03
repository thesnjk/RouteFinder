package com.routefinder.fleetdriver.fleet

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

data class FleetTrip(
    val id: String,
    val orgId: String,
    val vehicleId: String,
    val status: String,
    val stops: List<FleetTripStop>,
    val physicsETASeconds: Double?,
    val updatedAt: String,
)

data class FleetDispatchEvent(
    val kind: String,
    val vehicleId: String,
    val tripId: String?,
    val timestamp: String,
)

fun FleetTrip.toSnapshotJson(statusOverride: String? = null): JSONObject {
    val ordered = JSONArray()
    stops.sortedBy { it.sequence }.forEach { ordered.put(it.id) }
    return JSONObject()
        .put("tripId", id)
        .put("status", statusOverride ?: status)
        .put("orderedStopIds", ordered)
        .put("physicsETASeconds", physicsETASeconds ?: JSONObject.NULL)
        .put("updatedAt", updatedAt)
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
    )
}

fun parseEvent(json: JSONObject): FleetDispatchEvent =
    FleetDispatchEvent(
        kind = json.getString("kind"),
        vehicleId = json.getString("vehicleId"),
        tripId = if (json.isNull("tripId")) null else json.optString("tripId", null),
        timestamp = json.optString("timestamp", ""),
    )
