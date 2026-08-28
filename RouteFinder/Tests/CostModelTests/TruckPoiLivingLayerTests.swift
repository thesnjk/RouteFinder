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
    #expect(ring.count >= 4)
    #expect(ring.first == ring.last)
    #expect(ring == UKLowEmissionZoneBoundaries.londonULEZ)
    for point in ring {
        #expect(point.count == 2)
        #expect((-180...180).contains(point[0]))
        #expect((-90...90).contains(point[1]))
    }
}

@Test func ukLezAuthoredZonesUseBoundaryRings() {
    for (zoneId, expectedRing) in UKLowEmissionZoneBoundaries.ringsByZoneId {
        let zone = try! #require(UKLowEmissionZoneCatalog.zones.first { $0.id == zoneId })
        #expect(zone.boundaryRing != nil)
        #expect(zone.avoidPolygonRing() == expectedRing)
        #expect(zone.avoidPolygonRing().first == zone.avoidPolygonRing().last)
    }
}

@Test func ukLezCatalogIncludesExpandedCoverage() {
    #expect(UKLowEmissionZoneCatalog.zones.count >= 11)
    let ids = Set(UKLowEmissionZoneCatalog.zones.map(\.id))
    #expect(ids.contains("manchester-caz"))
    #expect(ids.contains("glasgow-lez"))
    #expect(ids.contains("bradford-caz"))
    #expect(ids.contains("oxford-zez"))
    #expect(ids.contains("portsmouth-caz"))
}

@Test func ukLezPolygonContainsCentralPointsAndExcludesFarAway() {
    let london = try! #require(UKLowEmissionZoneCatalog.zones.first { $0.id == "london-ulez" })
    #expect(london.contains(Coordinate(latitude: 51.5074, longitude: -0.1278)))
    #expect(london.contains(Coordinate(latitude: 51.45, longitude: -0.20)))
    // Outside Greater London envelope (roughly Oxford).
    #expect(!london.contains(Coordinate(latitude: 51.7520, longitude: -1.2577)))

    let bath = try! #require(UKLowEmissionZoneCatalog.zones.first { $0.id == "bath-caz" })
    #expect(bath.contains(Coordinate(latitude: 51.3811, longitude: -2.3590)))
    #expect(!bath.contains(Coordinate(latitude: 51.45, longitude: -2.60)))
}

@Test func ukLezCircleFallbackWhenNoBoundaryRing() {
    let circleOnly = UKLowEmissionZoneCatalog.Zone(
        id: "test-circle",
        label: "Test",
        latitude: 51.5,
        longitude: -0.1,
        radiusMeters: 1_000,
        boundaryRing: nil
    )
    let ring = circleOnly.avoidPolygonRing(pointCount: 8)
    #expect(ring.count == 9)
    #expect(ring.first == ring.last)
    #expect(circleOnly.contains(Coordinate(latitude: 51.5, longitude: -0.1)))
    #expect(!circleOnly.contains(Coordinate(latitude: 52.0, longitude: -0.1)))
}

@Test func lezAvoidPolicyEuro6ProducesNoPolygons() {
    let rings = LEZAvoidPolicy.polygons(
        emissionClass: .euro6,
        avoidEnabled: true,
        destination: Coordinate(latitude: 52.0, longitude: -1.0)
    )
    #expect(rings.isEmpty)
}

@Test func lezAvoidPolicyEuro4ProducesUnderCapPolygons() {
    let rings = LEZAvoidPolicy.polygons(
        emissionClass: .euro4,
        avoidEnabled: true,
        destination: Coordinate(latitude: 52.0, longitude: -1.0)
    )
    let expected = UKLowEmissionZoneCatalog.zones.filter { zone in
        LEZAvoidPolicy.approximateRingAreaSquareMeters(zone.avoidPolygonRing())
            <= LEZAvoidPolicy.avoidPolygonAreaCapSquareMeters
    }
    #expect(rings.count == expected.count)
    #expect(rings.count < UKLowEmissionZoneCatalog.zones.count) // London ULEZ exceeds ORS cap
    #expect(rings.allSatisfy { $0.first == $0.last })
    #expect(rings.allSatisfy {
        LEZAvoidPolicy.approximateRingAreaSquareMeters($0) <= LEZAvoidPolicy.avoidPolygonAreaCapSquareMeters
    })
}

@Test func lezAvoidPolicyOmitsDestinationZone() {
    let london = Coordinate(latitude: 51.5074, longitude: -0.1278)
    let rings = LEZAvoidPolicy.polygons(
        emissionClass: .euro4,
        avoidEnabled: true,
        destination: london
    )
    let expectedWithoutLondon = UKLowEmissionZoneCatalog.zones.filter { zone in
        !zone.contains(london)
            && LEZAvoidPolicy.approximateRingAreaSquareMeters(zone.avoidPolygonRing())
            <= LEZAvoidPolicy.avoidPolygonAreaCapSquareMeters
    }
    #expect(rings.count == expectedWithoutLondon.count)
}

@Test func lezAvoidPolicyDisabledProducesNoPolygons() {
    let rings = LEZAvoidPolicy.polygons(
        emissionClass: .euro1,
        avoidEnabled: false,
        destination: nil
    )
    #expect(rings.isEmpty)
}

@Test func lezAvoidPolicyUnknownEmissionOmitsOversizedZones() {
    let rings = LEZAvoidPolicy.polygons(
        emissionClass: nil,
        avoidEnabled: true,
        destination: Coordinate(latitude: 55.0, longitude: -3.0)
    )
    let expected = UKLowEmissionZoneCatalog.zones.filter {
        LEZAvoidPolicy.approximateRingAreaSquareMeters($0.avoidPolygonRing())
            <= LEZAvoidPolicy.avoidPolygonAreaCapSquareMeters
    }
    #expect(rings.count == expected.count)
    #expect(!rings.isEmpty)
}

@Test func lezAvoidPolicyOmitsLondonAreaOverORSCap() {
    let london = UKLowEmissionZoneCatalog.zones.first { $0.id == "london-ulez" }!
    let area = LEZAvoidPolicy.approximateRingAreaSquareMeters(london.avoidPolygonRing())
    #expect(area > LEZAvoidPolicy.avoidPolygonAreaCapSquareMeters)

    let rings = LEZAvoidPolicy.polygons(
        emissionClass: .euro4,
        avoidEnabled: true,
        destination: Coordinate(latitude: 55.0, longitude: -3.0),
        zones: [london]
    )
    #expect(rings.isEmpty)
}

@Test func lezAvoidPolicyOmitsPolygonsOnLongHaul() {
    let norwich = Coordinate(latitude: 52.63, longitude: 1.30)
    let alesund = Coordinate(latitude: 62.47, longitude: 6.15)
    let rings = LEZAvoidPolicy.polygons(
        emissionClass: .euro4,
        avoidEnabled: true,
        destination: alesund,
        origin: norwich
    )
    #expect(rings.isEmpty)
}

@Test func lezAvoidPolicyKeepsPolygonsOnShortUKHop() {
    let norwich = Coordinate(latitude: 52.63, longitude: 1.30)
    let nearby = Coordinate(latitude: 52.65, longitude: 1.28)
    let rings = LEZAvoidPolicy.polygons(
        emissionClass: .euro4,
        avoidEnabled: true,
        destination: nearby,
        origin: norwich
    )
    #expect(!rings.isEmpty)
    #expect(rings.allSatisfy {
        LEZAvoidPolicy.approximateRingAreaSquareMeters($0) <= LEZAvoidPolicy.avoidPolygonAreaCapSquareMeters
    })
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
