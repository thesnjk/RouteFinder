package com.routefinder.fleetdriver.routing

/**
 * Named UK toll / tolled crossing advisory with optional static indicative £.
 * Mirrors iOS ``UKTollAdvisory`` / ``UKTollAdvisoryCatalog`` — planning aids, not live tariffs.
 */
data class UKTollAdvisory(
    val id: String,
    val name: String,
    val latitude: Double,
    val longitude: Double,
    val approachRadiusMeters: Double = 2_500.0,
    val hint: String,
    val infoURL: String? = null,
    val indicativeCostGBP: Double? = null,
    val indicativeCostNote: String? = null,
) {
    val coordinate: LatLon get() = LatLon(latitude, longitude)

    /** Driver-facing “Indicative ~£X” line when a static £ is seeded. */
    val indicativeCostLabel: String?
        get() {
            val gbp = indicativeCostGBP ?: return null
            val amount = String.format("£%.2f", gbp)
            val note = indicativeCostNote
            return if (!note.isNullOrEmpty()) {
                "Indicative ~$amount ($note)"
            } else {
                "Indicative ~$amount"
            }
        }

    companion object {
        fun indicativeRouteTotalGBP(advisories: List<UKTollAdvisory>): Double? {
            val amounts = advisories.mapNotNull { it.indicativeCostGBP }
            if (amounts.isEmpty()) return null
            return amounts.sum()
        }

        fun indicativeRouteTotalLabel(advisories: List<UKTollAdvisory>): String? {
            val total = indicativeRouteTotalGBP(advisories) ?: return null
            return String.format("Indicative tolls ~£%.2f", total)
        }
    }
}

/** Hand-authored UK toll / crossing points (same seeds as iOS; as-of 2025-10). */
object UKTollAdvisoryCatalog {
    val all: List<UKTollAdvisory> = listOf(
        UKTollAdvisory(
            id = "m6-toll",
            name = "M6 Toll",
            latitude = 52.6500,
            longitude = -1.7500,
            approachRadiusMeters = 4_000.0,
            hint = "Private motorway — class-based charges; tag or account.",
            infoURL = "https://www.m6toll.co.uk/",
            indicativeCostGBP = 13.00,
            indicativeCostNote = "indicative HGV class; check M6 Toll",
        ),
        UKTollAdvisory(
            id = "dartford-crossing",
            name = "Dartford Crossing",
            latitude = 51.4640,
            longitude = 0.2580,
            approachRadiusMeters = 3_500.0,
            hint = "Dart Charge — pay by midnight next day for most vehicles.",
            infoURL = "https://www.gov.uk/dart-charge",
            indicativeCostGBP = 6.00,
            indicativeCostNote = "indicative HGV day; check GOV.UK",
        ),
        UKTollAdvisory(
            id = "mersey-gateway",
            name = "Mersey Gateway",
            latitude = 53.3500,
            longitude = -2.7300,
            approachRadiusMeters = 3_000.0,
            hint = "Merseyflow account or pay-as-you-go. Silver Jubilee Bridge free for most local traffic.",
            infoURL = "https://www.merseyflow.co.uk/",
            indicativeCostGBP = 4.00,
            indicativeCostNote = "indicative; check Merseyflow class",
        ),
        UKTollAdvisory(
            id = "severn-crossings",
            name = "Severn Bridge / Second Severn Crossing",
            latitude = 51.5900,
            longitude = -2.7000,
            approachRadiusMeters = 4_000.0,
            hint = "Severn Bridge tolls ended 2018 — free crossing. Historic entry retained for map context.",
            infoURL = "https://www.gov.uk/government/news/severn-crossing-tolls-to-end",
        ),
        UKTollAdvisory(
            id = "humber-bridge",
            name = "Humber Bridge",
            latitude = 53.7070,
            longitude = -0.4500,
            approachRadiusMeters = 2_500.0,
            hint = "Tolled bridge — HGV class rates apply. Pay at plaza or check operator site.",
            infoURL = "https://www.humberbridge.co.uk/",
            indicativeCostGBP = 5.00,
            indicativeCostNote = "indicative; check Humber Bridge",
        ),
        UKTollAdvisory(
            id = "tyne-tunnel",
            name = "Tyne Tunnel",
            latitude = 54.9860,
            longitude = -1.4800,
            approachRadiusMeters = 2_500.0,
            hint = "TT2 account recommended for HGVs. Day rates vary by vehicle class.",
            infoURL = "https://www.tt2.co.uk/",
            indicativeCostGBP = 3.00,
            indicativeCostNote = "indicative; check TT2",
        ),
        UKTollAdvisory(
            id = "tamar-bridge",
            name = "Tamar Bridge",
            latitude = 50.4080,
            longitude = -4.2040,
            approachRadiusMeters = 2_000.0,
            hint = "Toll westbound (into Cornwall). Check current HGV tariffs with the authority.",
            infoURL = "https://www.tamarcrossings.org.uk/",
            indicativeCostGBP = 3.00,
            indicativeCostNote = "westbound indicative; check authority",
        ),
        UKTollAdvisory(
            id = "forth-road-bridge",
            name = "Forth Road Bridge / Queensferry Crossing",
            latitude = 56.0000,
            longitude = -3.4000,
            approachRadiusMeters = 3_500.0,
            hint = "Queensferry Crossing is the main HGV route; Forth Road Bridge restricted. No toll on Queensferry.",
            infoURL = "https://www.transport.gov.scot/",
        ),
        UKTollAdvisory(
            id = "erksine-bridge",
            name = "Erskine Bridge",
            latitude = 55.9200,
            longitude = -4.4600,
            approachRadiusMeters = 2_000.0,
            hint = "Scotland — free for most traffic; check any temporary restrictions.",
        ),
        UKTollAdvisory(
            id = "clyde-tunnel",
            name = "Clyde Tunnel",
            latitude = 55.8600,
            longitude = -4.3200,
            approachRadiusMeters = 1_500.0,
            hint = "Height/vehicle restrictions may apply — verify before routing HGV through tunnels.",
        ),
        UKTollAdvisory(
            id = "blackwall-tunnel",
            name = "Blackwall Tunnel",
            latitude = 51.5030,
            longitude = 0.0030,
            approachRadiusMeters = 2_000.0,
            hint = "Not a toll — height and HGV restrictions; Silvertown Tunnel may divert traffic.",
            infoURL = "https://tfl.gov.uk/",
        ),
        UKTollAdvisory(
            id = "silvertown-tunnel",
            name = "Silvertown Tunnel",
            latitude = 51.5020,
            longitude = 0.0200,
            approachRadiusMeters = 2_500.0,
            hint = "User charge applies — check TfL for HGV rates and exemptions.",
            infoURL = "https://tfl.gov.uk/modes/driving/silvertown-tunnel",
            indicativeCostGBP = 4.00,
            indicativeCostNote = "indicative TfL user charge; check class",
        ),
        UKTollAdvisory(
            id = "conwy-tunnel",
            name = "Conwy Tunnel (A55)",
            latitude = 53.2800,
            longitude = -3.8300,
            approachRadiusMeters = 2_000.0,
            hint = "Free trunk road tunnel — height/ADR awareness; not a toll plaza.",
        ),
        UKTollAdvisory(
            id = "durham-a1m",
            name = "A1(M) Durham (historic toll context)",
            latitude = 54.7800,
            longitude = -1.5800,
            approachRadiusMeters = 3_000.0,
            hint = "No current toll on A1(M) Durham — catalog entry for corridor awareness only.",
        ),
        UKTollAdvisory(
            id = "itchen-bridge",
            name = "Itchen Bridge (Southampton)",
            latitude = 50.8970,
            longitude = -1.3850,
            approachRadiusMeters = 1_500.0,
            hint = "Local toll bridge — check Southampton City Council for current charges.",
            infoURL = "https://www.southampton.gov.uk/",
            indicativeCostGBP = 1.00,
            indicativeCostNote = "indicative local; check council",
        ),
        UKTollAdvisory(
            id = "whitchurch-bridge",
            name = "Whitchurch Bridge (Thames)",
            latitude = 51.4870,
            longitude = -1.0850,
            approachRadiusMeters = 1_200.0,
            hint = "Private toll bridge — weight limits; unsuitable for many HGVs.",
        ),
    )

    fun advisory(id: String): UKTollAdvisory? = all.firstOrNull { it.id == id }
}
