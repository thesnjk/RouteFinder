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

@Test func ukLezZoneAvoidPolygonRingIsClosed() {
    let zone = try! #require(UKLowEmissionZoneCatalog.zones.first { $0.id == "london-ulez" })
    let ring = zone.avoidPolygonRing(pointCount: 16)
    #expect(ring.count == 17)
    #expect(ring.first == ring.last)
    for point in ring {
        #expect(point.count == 2)
        #expect((-180...180).contains(point[0]))
        #expect((-90...90).contains(point[1]))
    }
}

@Test func lezAvoidPolicyEuro6ProducesNoPolygons() {
    let rings = LEZAvoidPolicy.polygons(
        emissionClass: .euro6,
        avoidEnabled: true,
        destination: Coordinate(latitude: 52.0, longitude: -1.0)
    )
    #expect(rings.isEmpty)
}

@Test func lezAvoidPolicyEuro4ProducesPolygons() {
    let rings = LEZAvoidPolicy.polygons(
        emissionClass: .euro4,
        avoidEnabled: true,
        destination: Coordinate(latitude: 52.0, longitude: -1.0)
    )
    #expect(rings.count == UKLowEmissionZoneCatalog.zones.count)
    #expect(rings.allSatisfy { $0.first == $0.last })
}

@Test func lezAvoidPolicyOmitsDestinationZone() {
    let london = Coordinate(latitude: 51.5074, longitude: -0.1278)
    let rings = LEZAvoidPolicy.polygons(
        emissionClass: .euro4,
        avoidEnabled: true,
        destination: london
    )
    #expect(rings.count == UKLowEmissionZoneCatalog.zones.count - 1)
}

@Test func lezAvoidPolicyDisabledProducesNoPolygons() {
    let rings = LEZAvoidPolicy.polygons(
        emissionClass: .euro1,
        avoidEnabled: false,
        destination: nil
    )
    #expect(rings.isEmpty)
}

@Test func lezAvoidPolicyUnknownEmissionAvoidsZones() {
    let rings = LEZAvoidPolicy.polygons(
        emissionClass: nil,
        avoidEnabled: true,
        destination: Coordinate(latitude: 55.0, longitude: -3.0)
    )
    #expect(rings.count == UKLowEmissionZoneCatalog.zones.count)
}

@Test func lezAnnouncementCopyForAvoidedAndDestinationInside() {
    let route = [
        Coordinate(latitude: 51.45, longitude: -0.2),
        Coordinate(latitude: 51.50, longitude: -0.13),
        Coordinate(latitude: 51.55, longitude: -0.05),
    ]
    let avoiding = UKLowEmissionZoneCatalog.announcements(
        along: route,
        emissionClass: .euro4,
        avoidEnabled: true,
        destination: Coordinate(latitude: 52.0, longitude: -1.0)
    )
    #expect(avoiding.contains { $0.message.contains("Avoiding") })

    let inside = UKLowEmissionZoneCatalog.announcements(
        along: route,
        emissionClass: .euro4,
        avoidEnabled: true,
        destination: Coordinate(latitude: 51.5074, longitude: -0.1278)
    )
    #expect(inside.contains { $0.message.contains("Destination inside") })
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
