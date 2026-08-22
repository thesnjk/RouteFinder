import Contracts
import CoreLocation
import Foundation
import RouteController
import Testing

struct SpeedLimitNormalizerTests {
    private var ukCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: 51.5074, longitude: -0.1278)
    }

    @Test func toKmh_convertsMphToKmh() {
        let kmh = SpeedLimitNormalizer.toKmh(rawValue: 60, nativeUnit: .mph)
        #expect(abs(kmh - 96.5604) < 0.1)
    }

    @Test func toKmh_passthroughMetric() {
        #expect(SpeedLimitNormalizer.toKmh(rawValue: 80, nativeUnit: .kmh) == 80)
    }

    @Test func correctDesignSpeedKmh_fixesImperialSixty() {
        let corrected = SpeedLimitNormalizer.correctDesignSpeedKmh(
            designKmh: 60,
            measurementSystem: .imperial,
            roadLabel: "Continue on M60"
        )
        #expect(corrected > 90)
        #expect(corrected < 100)
    }

    @Test func correctDesignSpeedKmh_leavesMetricUnchanged() {
        #expect(
            SpeedLimitNormalizer.correctDesignSpeedKmh(
                designKmh: 60,
                measurementSystem: .metric,
                roadLabel: "Rural Lane"
            ) == 60
        )
    }

    @Test func normalizeToKmh_usesGeographyForImperialSignValues() {
        let kmh = SpeedLimitNormalizer.normalizeToKmh(rawValue: 60, coordinate: ukCoordinate)
        #expect(kmh > 90)
    }
}
