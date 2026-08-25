import Contracts
import Foundation
import Testing

@Test func commercialPoiEngineFiltersAheadWithin20Miles() {
    let pois = [
        TruckPoi(
            id: "1",
            kind: .highFlowDiesel,
            latitude: 51.5,
            longitude: -0.1,
            label: "Near fuel",
            arcLengthAlongRouteMeters: 5_000,
            confidence: 0.9
        ),
        TruckPoi(
            id: "2",
            kind: .highFlowDiesel,
            latitude: 52.0,
            longitude: 0.0,
            label: "Far fuel",
            arcLengthAlongRouteMeters: 50_000,
            confidence: 0.9
        ),
        TruckPoi(
            id: "3",
            kind: .weighStation,
            latitude: 51.6,
            longitude: -0.2,
            label: "Weigh",
            arcLengthAlongRouteMeters: 8_000,
            confidence: 0.8
        ),
    ]

    let ahead = CommercialPoiEngine.ahead(
        pois: pois,
        fromArcLengthMeters: 0,
        aheadMeters: TruckPoiSearchDefaults.twentyMilesMeters,
        kinds: [.highFlowDiesel]
    )

    #expect(ahead.count == 1)
    #expect(ahead.first?.id == "1")
}

@Test func ukLezCatalogDetectsLondonCorridor() {
    let route = [
        Coordinate(latitude: 51.45, longitude: -0.2),
        Coordinate(latitude: 51.50, longitude: -0.13),
        Coordinate(latitude: 51.55, longitude: -0.05),
    ]
    let announcements = UKLowEmissionZoneCatalog.announcements(along: route)
    #expect(announcements.contains { $0.zoneId == "london-ulez" })
}

@Test func poiConfidenceAdjusterReducesNearClosure() {
    let poi = TruckPoi(
        id: "p1",
        kind: .overnightSecureParking,
        latitude: 51.5,
        longitude: -0.1,
        label: "Yard",
        confidence: 0.9
    )
    let report = CrowdReport(
        latitude: 51.5001,
        longitude: -0.1001,
        type: .closure,
        reporterId: "driver-1"
    )
    let adjusted = PoiConfidenceAdjuster.adjust(pois: [poi], reports: [report])
    #expect((adjusted.first?.confidence ?? 1) < 0.9)
}
