import Contracts
import DataLayer
import Foundation
import RouteController
import Testing

@Suite("Job intake and predictive risk")
struct JobIntakePredictiveRiskTests {
    @Test func jobBriefAppliesWeightAndADR() {
        let brief = FleetJobBrief(grossWeightKg: 40_000, adrClass: "3", autoFindRoute: true)
        let profile = brief.applyingWeight(to: .ukArtic)
        #expect(profile?.weight == 40)
        #expect(profile?.hazmatClass == .class3)
        #expect(FleetJobBrief.hazmatClass(fromADR: "class2") == .class2)
    }

    @Test func jobIntakeMapperOrdersStopsAndPolicy() {
        let trip = FleetTrip(
            orgId: UUID(),
            vehicleId: UUID(),
            stops: [
                FleetTripStop(sequence: 1, label: "B", latitude: 1, longitude: 1, role: .destination),
                FleetTripStop(sequence: 0, label: "A", latitude: 0, longitude: 0, role: .origin),
            ],
            vehicleProfile: .ukArtic,
            jobBrief: FleetJobBrief(grossWeightKg: 26_000, autoFindRoute: false, autoRehearse: true)
        )
        let ordered = JobIntakeMapper.orderedStops(from: trip)
        #expect(ordered.first?.label == "A")
        #expect(JobIntakeMapper.effectiveProfile(from: trip)?.weight == 26)
        #expect(JobIntakePolicy.fleetPilot.shouldAutoFindRoute(brief: trip.jobBrief) == false)
        #expect(JobIntakePolicy.fleetPilot.shouldAutoRehearse(brief: trip.jobBrief) == true)
    }

    @Test func dispatchDraftBuildsJobBrief() {
        var draft = DispatchTripDraft.ukDemoTemplate()
        draft.grossWeightKgText = "44000"
        draft.adrClassText = "8"
        let brief = draft.jobBrief()
        #expect(brief.grossWeightKg == 44_000)
        #expect(brief.adrClass == "8")
        #expect(brief.autoFindRoute == true)
    }

    @Test func predictiveRiskEngineFusesThreeKinds() {
        let hazard = HazardAheadAnnouncement(
            id: "h1",
            type: .closure,
            distanceRemainingMeters: 1_200,
            message: "Closure ahead",
            source: "test"
        )
        let advisories = PredictiveRiskEngine.fuse(
            snapshot: PredictiveRiskSnapshot(
                kineticMessage: "Steep descent ahead",
                kineticDistanceMeters: 800,
                weatherMessage: "Heavy rain on corridor",
                weatherDistanceMeters: 2_000,
                hazard: hazard,
                roadworksMessage: nil,
                trafficMessage: nil
            )
        )
        let kinds = Set(advisories.map(\.kind))
        #expect(kinds.contains(.kinetic))
        #expect(kinds.contains(.weather))
        #expect(kinds.contains(.hazard))
        #expect(kinds.count >= 3)
        let primary = RouteRiskFormatter.primaryAhead(advisories: advisories)
        #expect(primary?.kind == .hazard)
    }

    @Test func tripBriefIncludesDispatchTimeWindows() {
        let stopId = UUID()
        let window = StopTimeWindow(
            stopId: stopId,
            earliestArrival: Date(timeIntervalSince1970: 1_700_000_000),
            latestArrival: Date(timeIntervalSince1970: 1_700_003_600)
        )
        let trip = FleetTrip(
            orgId: UUID(),
            vehicleId: UUID(),
            stops: [
                FleetTripStop(id: stopId, sequence: 0, label: "Depot", latitude: 53.48, longitude: -2.24, role: .destination),
                FleetTripStop(sequence: 1, label: "Port", latitude: 51.95, longitude: 1.35, role: .origin),
            ],
            jobBrief: FleetJobBrief(timeWindows: [window])
        )
        let context = TripBriefContext.from(fleetTrip: trip, vehicleLabel: "Artic 1")
        #expect(context.dispatchTimeWindows.count == 1)
        let text = TripBriefFormatter.plainText(from: context)
        #expect(text.contains("Stop time windows"))
        #expect(text.contains("Depot"))
    }

    @Test func timeWindowRiskEvaluatorFlagsLateETA() {
        let stopId = UUID()
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let window = StopTimeWindow(
            stopId: stopId,
            latestArrival: now.addingTimeInterval(30 * 60)
        )
        let result = TimeWindowRiskEvaluator.advisory(
            windows: [window],
            stops: [
                FleetTripStop(id: stopId, sequence: 0, label: "Manchester", latitude: 53.48, longitude: -2.24, role: .destination),
            ],
            physicsETASeconds: 2 * 3_600,
            now: now
        )
        #expect(result != nil)
        #expect(result?.message.contains("Manchester") == true)
        #expect(result?.message.contains("late") == true)
    }

    @Test func predictiveRiskEngineFusesScheduleLateAsTraffic() {
        let advisories = PredictiveRiskEngine.fuse(
            snapshot: PredictiveRiskSnapshot(
                scheduleLateMessage: "Projected late to Depot by 40 min (dispatch window)",
                scheduleLateDistanceMeters: 12_000
            )
        )
        #expect(advisories.contains { $0.source == "timeWindow" && $0.kind == .traffic })
    }

    @Test func forecastRiskSamplerMapsCongestionAndWeather() {
        let flow = TomTomFlowSegmentData(
            currentSpeedKmh: 10,
            freeFlowSpeedKmh: 80,
            confidence: 0.9,
            roadClosed: false
        )
        let traffic = ForecastRiskSampler.trafficAdvisory(
            flow: flow,
            arcLengthMeters: 60_000,
            currentArcLengthMeters: 0
        )
        #expect(traffic?.kind == .traffic)
        #expect(traffic?.source == "forecastTomTom")

        let weather = ForecastRiskSampler.weatherAdvisory(
            conditionMain: "Rain",
            windGustMps: 22,
            visibilityMeters: 800,
            arcLengthMeters: 120_000,
            currentArcLengthMeters: 0
        )
        #expect(weather?.kind == .weather)
        #expect(weather?.source == "forecastOpenWeather")
    }

    @Test func clearanceCorridorProbeFlagsHeightConflict() {
        let hit = ClearanceCorridorProbe.ClearanceRestrictionHit(
            id: "node/1",
            latitude: 51.5,
            longitude: -0.1,
            arcLengthAlongRouteMeters: 2_500,
            maxHeightMeters: 3.8,
            label: "Low bridge"
        )
        let advisories = ClearanceCorridorProbe.advisories(
            from: [hit],
            profile: .ukArtic,
            currentArcLengthMeters: 0
        )
        #expect(advisories.count == 1)
        #expect(advisories[0].kind == .clearance)
        #expect(advisories[0].severity == .severe)
        #expect(ClearanceCorridorProbe.parseMeters("4.2 m") == 4.2)
        #expect(ClearanceCorridorProbe.parseTonnes("18000 kg") == 18)
    }

    @Test func clearanceHeadingCorridorBuildsPolyline() {
        let origin = Coordinate(latitude: 52.6, longitude: 1.3)
        let corridor = ClearanceCorridorProbe.headingCorridor(
            from: origin,
            bearingDegrees: 90,
            lengthMeters: 1_000,
            stepMeters: 250
        )
        #expect(corridor.count >= 4)
        #expect(corridor.first == origin)
        // Eastbound: longitude increases.
        #expect(corridor.last!.longitude > origin.longitude)
    }

    @Test func clearanceIsOffRouteWhenFarFromSpine() {
        let route = [
            Coordinate(latitude: 52.60, longitude: 1.30),
            Coordinate(latitude: 52.61, longitude: 1.30),
        ]
        let onRoute = ClearanceCorridorProbe.isOffRoute(
            point: Coordinate(latitude: 52.605, longitude: 1.3001),
            route: route
        )
        #expect(onRoute.offRoute == false)
        let off = ClearanceCorridorProbe.isOffRoute(
            point: Coordinate(latitude: 52.605, longitude: 1.32),
            route: route
        )
        #expect(off.offRoute == true)
        #expect(off.crossTrackMeters > ClearanceCorridorProbe.offRouteCrossTrackThresholdMeters)
    }

    @Test func predictiveRiskEnginePrefersSevereForecast() {
        let forecast = RouteRiskAdvisory(
            id: "f1",
            kind: .traffic,
            severity: .severe,
            distanceRemainingMeters: 50_000,
            message: "Forecast bottleneck",
            spokenPrompt: "Forecast bottleneck",
            source: "forecastTomTom"
        )
        let advisories = PredictiveRiskEngine.fuse(
            snapshot: PredictiveRiskSnapshot(
                kineticMessage: "Grade ahead",
                kineticDistanceMeters: 800,
                forecastItems: [forecast]
            )
        )
        let primary = RouteRiskFormatter.primaryAhead(advisories: advisories, maxAheadMeters: 80_000)
        #expect(primary?.id == "f1")
    }

    @Test func inspectionMediaBudgetCapsPhotosAndPDF() {
        let oversized = Data(repeating: 0xFF, count: InspectionMediaBudget.maxPhotoBytes + 50)
        #expect(InspectionMediaBudget.cappedJPEG(oversized).count == InspectionMediaBudget.maxPhotoBytes)
        let pdf = String(repeating: "A", count: InspectionMediaBudget.maxPDFBase64Characters + 10)
        #expect(InspectionMediaBudget.cappedPDFBase64(pdf)?.count == InspectionMediaBudget.maxPDFBase64Characters)
    }

    @Test func inspectionItemRoundTripsPhotoBase64() throws {
        let item = InspectionChecklistItem(
            zone: .lights,
            label: "Side lights",
            status: .defect,
            note: "Cracked",
            photoJPEGBase64: ["aGVsbG8="]
        )
        let data = try JSONEncoder().encode(item)
        let decoded = try JSONDecoder().decode(InspectionChecklistItem.self, from: data)
        #expect(decoded.photoJPEGBase64 == ["aGVsbG8="])
    }
}
