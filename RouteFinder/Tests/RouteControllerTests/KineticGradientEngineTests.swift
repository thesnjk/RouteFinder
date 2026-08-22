import Contracts
import Foundation
import Testing
@testable import RouteController

struct KineticGradientEngineTests {
    @Test func flatPath_returnsNeutralStress() async {
        let engine = KineticGradientEngine()
        let path = [
            GeoCoordinate3D(latitude: 51.5, longitude: -0.12, elevationMeters: 100),
            GeoCoordinate3D(latitude: 51.51, longitude: -0.12, elevationMeters: 100),
            GeoCoordinate3D(latitude: 51.52, longitude: -0.12, elevationMeters: 100),
        ]

        let stress = await engine.analyzeTopology(path: path, weightTons: 44.0)

        #expect(stress.count == 2)
        #expect(stress.allSatisfy { $0.gradePercentage == 0 })
        #expect(stress.allSatisfy { $0.loadMultiplier == 1 })
        #expect(stress.allSatisfy { $0.thermalStressScore == 0 })
    }

    @Test func uphillGrade_increasesLoadMultiplier() async {
        let engine = KineticGradientEngine()
        let path = [
            GeoCoordinate3D(latitude: 51.5, longitude: -0.12, elevationMeters: 0),
            GeoCoordinate3D(latitude: 51.51, longitude: -0.12, elevationMeters: 50),
        ]

        let stress = await engine.analyzeTopology(path: path, weightTons: 44.0)

        #expect(stress.count == 1)
        #expect(stress[0].gradePercentage > 2)
        #expect(stress[0].loadMultiplier > 1)
    }

    @Test func downhillGrade_increasesThermalOnly() async {
        let engine = KineticGradientEngine()
        let path = [
            GeoCoordinate3D(latitude: 51.5, longitude: -0.12, elevationMeters: 200),
            GeoCoordinate3D(latitude: 51.51, longitude: -0.12, elevationMeters: 0),
        ]

        let stress = await engine.analyzeTopology(path: path, weightTons: 44.0)

        #expect(stress.count == 1)
        #expect(stress[0].gradePercentage < -2)
        #expect(stress[0].thermalStressScore > 0)
        #expect(stress[0].loadMultiplier == 1)
    }

    @Test func heavyVehicle_scalesUphillLoadMoreThanLight() async {
        let engine = KineticGradientEngine()
        let path = [
            GeoCoordinate3D(latitude: 51.5, longitude: -0.12, elevationMeters: 0),
            GeoCoordinate3D(latitude: 51.51, longitude: -0.12, elevationMeters: 40),
        ]

        let heavy = await engine.analyzeTopology(path: path, weightTons: 44.0)
        let light = await engine.analyzeTopology(path: path, weightTons: 7.5)

        #expect(heavy[0].loadMultiplier > light[0].loadMultiplier)
    }

    @Test func buildProfile_resolvesStressByArcLength() async {
        let engine = KineticGradientEngine()
        let path = [
            GeoCoordinate3D(latitude: 51.5, longitude: -0.12, elevationMeters: 0),
            GeoCoordinate3D(latitude: 51.51, longitude: -0.12, elevationMeters: 50),
            GeoCoordinate3D(latitude: 51.52, longitude: -0.12, elevationMeters: 50),
        ]

        let profile = await engine.buildProfile(path: path, weightTons: 44.0)
        let earlyStress = profile.stress(atArcLength: 0)
        let lateStress = profile.stress(atArcLength: 50_000)

        #expect(earlyStress.loadMultiplier > 1)
        #expect(lateStress.gradePercentage == 0)
    }
}
