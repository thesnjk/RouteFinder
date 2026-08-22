import Contracts
import CoreLocation
import Foundation
import RouteController
import Testing
@testable import UI

struct SimulationSpeedProfileTests {
    private var ukCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: 51.5074, longitude: -0.1278)
    }

    private var osloCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: 59.9139, longitude: 10.7522)
    }

    @Test func localProfile_defaultsTo48KmhInUK() {
        let profile = SimulationSpeedProfile(
            maneuvers: [
                ExternalManeuver(
                    instruction: "Continue on Church Lane",
                    distanceMeters: 500,
                    durationSeconds: 0
                ),
            ],
            turnInstructions: [
                TurnInstruction(
                    maneuver: .straight,
                    roadName: "Church Lane",
                    distance: 500,
                    bearing: 90
                ),
            ],
            isPassengerCar: false,
            routeCoordinate: ukCoordinate
        )

        #expect(profile.legalLimitKmh(at: 100) == 48)
    }

    @Test func localProfile_defaultsTo50KmhInMetricRegion() {
        let profile = SimulationSpeedProfile(
            maneuvers: [
                ExternalManeuver(
                    instruction: "Continue on Kirkegata",
                    distanceMeters: 500,
                    durationSeconds: 0
                ),
            ],
            turnInstructions: [
                TurnInstruction(
                    maneuver: .straight,
                    roadName: "Kirkegata",
                    distance: 500,
                    bearing: 90
                ),
            ],
            isPassengerCar: false,
            routeCoordinate: osloCoordinate
        )

        #expect(profile.legalLimitKmh(at: 100) == 50)
    }

    @Test func localProfile_motorwayKeyword_capsAt96ForHGVInUK() {
        let profile = SimulationSpeedProfile(
            maneuvers: [
                ExternalManeuver(
                    instruction: "Continue on A47 Motorway",
                    distanceMeters: 2000,
                    durationSeconds: 60
                ),
            ],
            turnInstructions: [
                TurnInstruction(
                    maneuver: .straight,
                    roadName: "A47 Motorway",
                    distance: 2000,
                    bearing: 90
                ),
            ],
            isPassengerCar: false,
            routeCoordinate: ukCoordinate
        )

        #expect(profile.legalLimitKmh(at: 500) == 96)
    }

    @Test func localProfile_motorwayKeyword_capsAt80ForHGVInMetricRegion() {
        let profile = SimulationSpeedProfile(
            maneuvers: [
                ExternalManeuver(
                    instruction: "Continue on E6 Motorway",
                    distanceMeters: 2000,
                    durationSeconds: 60
                ),
            ],
            turnInstructions: [
                TurnInstruction(
                    maneuver: .straight,
                    roadName: "E6 Motorway",
                    distance: 2000,
                    bearing: 90
                ),
            ],
            isPassengerCar: false,
            routeCoordinate: osloCoordinate
        )

        #expect(profile.legalLimitKmh(at: 500) == 80)
    }

    @Test func localProfile_motorwayKeyword_capsAt112ForCarInUK() {
        let profile = SimulationSpeedProfile(
            maneuvers: [
                ExternalManeuver(
                    instruction: "Continue on A11",
                    distanceMeters: 3000,
                    durationSeconds: 90
                ),
            ],
            turnInstructions: [
                TurnInstruction(
                    maneuver: .straight,
                    roadName: "A11",
                    distance: 3000,
                    bearing: 90
                ),
            ],
            isPassengerCar: true,
            routeCoordinate: ukCoordinate
        )

        #expect(profile.legalLimitKmh(at: 1000) == 112)
    }

    @Test func localProfile_designSpeedFromStepDuration() {
        let limit = SimulationSpeedProfile.resolveLimitKmh(
            roadLabel: "Rural Lane",
            distanceMeters: 1000,
            durationSeconds: 50,
            vehicleCeiling: 96
        )

        #expect(limit == 72)
    }

    @Test func resolveLimit_isMajorRoad_detectsNumberedARoad() {
        #expect(SimulationSpeedProfile.isMajorRoad("Continue on A40"))
        #expect(SimulationSpeedProfile.isMajorRoad("A-road near Norwich"))
        #expect(!SimulationSpeedProfile.isMajorRoad("High Street"))
    }

    @Test func resolveLimit_isMajorRoad_detectsMRoad() {
        #expect(SimulationSpeedProfile.isMajorRoad("Continue on M60"))
        #expect(SimulationSpeedProfile.isMajorRoad("Merge onto m6"))
    }

    @Test func localProfile_mRoad_capsAt112ForCarInUK() {
        let profile = SimulationSpeedProfile(
            maneuvers: [
                ExternalManeuver(
                    instruction: "Continue on M60",
                    distanceMeters: 3000,
                    durationSeconds: 120
                ),
            ],
            turnInstructions: [
                TurnInstruction(
                    maneuver: .straight,
                    roadName: "M60",
                    distance: 3000,
                    bearing: 90
                ),
            ],
            isPassengerCar: true,
            routeCoordinate: ukCoordinate
        )

        #expect(profile.legalLimitKmh(at: 1000) == 112)
        #expect(profile.limitDetails(at: 1000).source == .majorRoadCeiling)
    }

    @Test func resolveLimit_correctsImperialDesignSpeed() {
        let resolved = SimulationSpeedProfile.resolveLimit(
            roadLabel: "Country Road",
            distanceMeters: 1000,
            durationSeconds: 60,
            explicitLimitKmh: nil,
            vehicleCeiling: 112,
            defaultSpeedKmh: 48,
            measurementSystem: .imperial
        )

        #expect(resolved.speedKmh > 90)
        #expect(resolved.source == .correctedImperial)
    }
}
