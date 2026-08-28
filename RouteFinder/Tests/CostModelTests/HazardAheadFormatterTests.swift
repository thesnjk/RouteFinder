import Contracts
import Foundation
import Testing

struct HazardAheadFormatterTests {
    @Test func shouldAnnounceInsideThresholdOnce() {
        let announcement = HazardAheadAnnouncement(
            id: "h1",
            type: .closure,
            distanceRemainingMeters: 2500,
            message: "Closure ahead",
            source: "crowd:test"
        )
        #expect(HazardAheadFormatter.shouldAnnounce(
            announcement: announcement,
            lastAnnouncedHazardId: nil
        ))
        #expect(!HazardAheadFormatter.shouldAnnounce(
            announcement: announcement,
            lastAnnouncedHazardId: "h1"
        ))
    }

    @Test func shouldNotAnnounceOutsideThreshold() {
        let announcement = HazardAheadAnnouncement(
            id: "h1",
            type: .closure,
            distanceRemainingMeters: 4000,
            message: "Closure ahead",
            source: "crowd:test"
        )
        #expect(!HazardAheadFormatter.shouldAnnounce(
            announcement: announcement,
            lastAnnouncedHazardId: nil,
            alertDistanceMeters: 3000
        ))
    }

    @Test func spokenPromptMentionsClosure() {
        let announcement = HazardAheadAnnouncement(
            id: "h1",
            type: .closure,
            distanceRemainingMeters: 1609,
            message: "",
            source: "crowd:test"
        )
        #expect(HazardAheadFormatter.spokenPrompt(for: announcement).contains("closure"))
    }

    @Test func nearestAheadPicksClosestClosureOnRoute() {
        let route = [
            Coordinate(latitude: 51.50, longitude: -0.10),
            Coordinate(latitude: 51.55, longitude: -0.05),
            Coordinate(latitude: 51.60, longitude: 0.00),
        ]
        let hazards = [
            HazardEvent(
                id: "far",
                latitude: 51.59,
                longitude: -0.01,
                radiusMeters: 90,
                type: .closure,
                severity: .high,
                validFrom: Date().addingTimeInterval(-60),
                validTo: Date().addingTimeInterval(3600),
                source: "crowd:a"
            ),
            HazardEvent(
                id: "near",
                latitude: 51.52,
                longitude: -0.08,
                radiusMeters: 90,
                type: .closure,
                severity: .high,
                validFrom: Date().addingTimeInterval(-60),
                validTo: Date().addingTimeInterval(3600),
                source: "crowd:b"
            ),
        ]
        let result = HazardAheadFormatter.nearestAhead(
            hazards: hazards,
            crowdReports: [],
            route: route,
            currentArcLengthMeters: 0
        )
        #expect(result?.id == "near")
    }

    @Test func tomTomHitWinsWhenCloserThanCrowdHazard() {
        let route = [
            Coordinate(latitude: 51.50, longitude: -0.10),
            Coordinate(latitude: 51.55, longitude: -0.05),
            Coordinate(latitude: 51.60, longitude: 0.00),
        ]
        let hazards = [
            HazardEvent(
                id: "crowd-far",
                latitude: 51.58,
                longitude: -0.02,
                radiusMeters: 90,
                type: .closure,
                severity: .high,
                validFrom: Date().addingTimeInterval(-60),
                validTo: Date().addingTimeInterval(3600),
                source: "crowd:a"
            ),
        ]
        let tomTomHit = TomTomTrafficHazardHit(
            id: "tomtom-near",
            latitude: 51.51,
            longitude: -0.09,
            arcLengthAlongRouteMeters: 2500,
            isRoadClosed: false
        )
        let result = HazardAheadFormatter.nearestAhead(
            hazards: hazards,
            crowdReports: [],
            route: route,
            currentArcLengthMeters: 0,
            tomTomHits: [tomTomHit]
        )
        #expect(result?.id == "tomtom-near")
        #expect(result?.source == "tomtom:live")
    }

    @Test func promotedHazardsRebuildsFromRecentCrowdReports() {
        let report = CrowdReport(
            latitude: 51.5,
            longitude: -0.1,
            type: .closure,
            reporterId: "driver-1"
        )
        let hazards = HazardAheadFormatter.promotedHazards(from: [report])
        #expect(hazards.count == 1)
        #expect(hazards.first?.type == .closure)
    }
}

struct RoadworksAheadFormatterTests {
    @Test func bannerMessageUsesMilesWhenFar() {
        let site = RoadworkSite(
            id: "rw1",
            label: "M25 works",
            latitude: 51.5,
            longitude: -0.1,
            arcLengthAlongRouteMeters: 10_000
        )
        let message = RoadworksAheadFormatter.bannerMessage(site: site, currentArcLengthMeters: 0)
        #expect(message?.contains("mi") == true)
    }

    @Test func nearestAheadSelectsSoonestSite() {
        let sites = [
            RoadworkSite(id: "a", latitude: 0, longitude: 0, arcLengthAlongRouteMeters: 8000),
            RoadworkSite(id: "b", latitude: 0, longitude: 0, arcLengthAlongRouteMeters: 3000),
        ]
        #expect(RoadworksAheadFormatter.nearestAhead(sites: sites, currentArcLengthMeters: 0)?.id == "b")
    }
}
