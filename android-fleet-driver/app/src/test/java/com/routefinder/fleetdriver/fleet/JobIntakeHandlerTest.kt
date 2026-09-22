package com.routefinder.fleetdriver.fleet

import com.routefinder.fleetdriver.fleet.JobIntakeHandler
import com.routefinder.fleetdriver.fleet.formatTimeWindowLines
import com.routefinder.fleetdriver.fleet.hazmatEnabled
import com.routefinder.fleetdriver.fleet.parseTrip
import com.routefinder.fleetdriver.fleet.toHgvVehicleProfile
import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class JobIntakeHandlerTest {
    @Test
    fun parseTrip_readsJobBrief() {
        val json = JSONObject(
            """
            {
              "id": "11111111-1111-1111-1111-111111111111",
              "orgId": "22222222-2222-2222-2222-222222222222",
              "vehicleId": "33333333-3333-3333-3333-333333333333",
              "status": "dispatched",
              "updatedAt": "2026-09-19T12:00:00Z",
              "jobBrief": {
                "grossWeightKg": 44000,
                "adrClass": "3",
                "autoFindRoute": false,
                "autoRehearse": true,
                "timeWindows": [
                  {
                    "stopId": "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb",
                    "earliestArrival": "2026-09-21T10:00:00Z",
                    "latestArrival": "2026-09-21T14:00:00Z"
                  }
                ]
              },
              "vehicleProfile": {
                "height": 4.0,
                "weight": 40.0,
                "width": 2.55,
                "length": 16.5,
                "axleWeight": 11.5
              },
              "stops": [
                {
                  "id": "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa",
                  "sequence": 0,
                  "label": "A",
                  "latitude": 52.6,
                  "longitude": 1.2,
                  "role": "origin"
                },
                {
                  "id": "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb",
                  "sequence": 1,
                  "label": "B",
                  "latitude": 52.7,
                  "longitude": 0.4,
                  "role": "destination"
                }
              ]
            }
            """.trimIndent(),
        )
        val trip = parseTrip(json)
        assertEquals(44000.0, trip.jobBrief?.grossWeightKg)
        assertEquals("3", trip.jobBrief?.adrClass)
        assertEquals(1, trip.jobBrief?.timeWindows?.size)
        assertEquals("bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb", trip.jobBrief?.timeWindows?.first()?.stopId)
        val lines = formatTimeWindowLines(trip)
        assertTrue(lines.any { it.contains("B") })
        assertFalse(JobIntakeHandler.shouldAutoFindRoute(trip))
        assertTrue(JobIntakeHandler.shouldAutoRehearse(trip))
        assertEquals("A", JobIntakeHandler.orderedStops(trip).first().label)
        val hgv = trip.toHgvVehicleProfile()
        assertEquals(44.0, hgv.weightTonnes, 0.001)
        assertEquals(4.0, hgv.heightMeters, 0.001)
        assertTrue(hgv.hazmat)
        assertTrue(hazmatEnabled(fromADR = "3"))
        assertFalse(hazmatEnabled(fromADR = null))
        assertFalse(hazmatEnabled(fromADR = "none"))
    }

    @Test
    fun orsRequest_includesHazmatWhenAdrPresent() {
        val trip = parseTrip(
            JSONObject(
                """
                {
                  "id": "11111111-1111-1111-1111-111111111111",
                  "orgId": "22222222-2222-2222-2222-222222222222",
                  "vehicleId": "33333333-3333-3333-3333-333333333333",
                  "status": "dispatched",
                  "updatedAt": "2026-09-19T12:00:00Z",
                  "jobBrief": { "grossWeightKg": 40000, "adrClass": "8" },
                  "stops": [
                    {
                      "id": "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa",
                      "sequence": 0,
                      "label": "A",
                      "latitude": 52.6,
                      "longitude": 1.2,
                      "role": "origin"
                    },
                    {
                      "id": "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb",
                      "sequence": 1,
                      "label": "B",
                      "latitude": 52.7,
                      "longitude": 0.4,
                      "role": "destination"
                    }
                  ]
                }
                """.trimIndent(),
            ),
        )
        val body = com.routefinder.fleetdriver.routing.OrsDirectionsRequest.buildJson(
            originLon = 1.2,
            originLat = 52.6,
            destinationLon = 0.4,
            destinationLat = 52.7,
            vehicle = trip.toHgvVehicleProfile(),
        )
        val restrictions = body
            .getJSONObject("options")
            .getJSONObject("profile_params")
            .getJSONObject("restrictions")
        assertTrue(restrictions.getBoolean("hazmat"))
        assertEquals(40.0, restrictions.getDouble("weight"), 0.001)
    }
}
