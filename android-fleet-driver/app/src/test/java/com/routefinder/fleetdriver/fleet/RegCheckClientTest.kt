package com.routefinder.fleetdriver.fleet

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Test

class RegCheckClientTest {
    @Test
    fun parseBody_readsHeightAndWeightFromXml() {
        val xml = """
            <Vehicle>
              <Height>4.0</Height>
              <GrossWeight>40000</GrossWeight>
              <Width>2.55</Width>
              <Length>16.5</Length>
            </Vehicle>
        """.trimIndent()
        val spec = RegCheckClient.parseBody(xml)
        assertNotNull(spec)
        assertEquals(4.0, spec!!.heightMeters!!, 0.001)
        assertEquals(40.0, spec.weightTonnes!!, 0.001)
    }

    @Test
    fun needsRegistrationLookup_whenProfileEmpty() {
        val trip = parseTrip(
            org.json.JSONObject(
                """
                {
                  "id": "11111111-1111-1111-1111-111111111111",
                  "orgId": "22222222-2222-2222-2222-222222222222",
                  "vehicleId": "33333333-3333-3333-3333-333333333333",
                  "status": "dispatched",
                  "updatedAt": "2026-09-19T12:00:00Z",
                  "stops": [
                    {"id":"aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa","sequence":0,"label":"A","latitude":1,"longitude":1,"role":"origin"},
                    {"id":"bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb","sequence":1,"label":"B","latitude":2,"longitude":2,"role":"destination"}
                  ]
                }
                """.trimIndent(),
            ),
        )
        assertTrue(needsRegistrationLookup(trip))
        assertFalse(needsRegistrationLookup(trip.copy(vehicleProfile = FleetVehicleProfile(height = 4.0))))
    }
}
