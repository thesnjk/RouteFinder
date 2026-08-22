import Contracts
import CoreLocation
import Foundation
import RouteController
import Testing

struct TelemetryUnitConverterTests {
    @Test func londonUsesImperialSystem() {
        let london = CLLocationCoordinate2D(latitude: 51.5074, longitude: -0.1278)
        #expect(TelemetryUnitConverter.measurementSystem(for: london) == .imperial)
    }

    @Test func osloUsesMetricSystem() {
        let oslo = CLLocationCoordinate2D(latitude: 59.9139, longitude: 10.7522)
        #expect(TelemetryUnitConverter.measurementSystem(for: oslo) == .metric)
    }

    @Test func newYorkUsesImperialSystem() {
        let newYork = CLLocationCoordinate2D(latitude: 40.7128, longitude: -74.0060)
        #expect(TelemetryUnitConverter.measurementSystem(for: newYork) == .imperial)
    }

    @Test func formatSpeedLimitConvertsKmhToMphForImperialDisplay() {
        let formatted = TelemetryUnitConverter.formatSpeedLimit(rawOsmValue: 50.0, targetSystem: .imperial)
        #expect(formatted == "31 mph")
    }

    @Test func formatSpeedLimitPreservesMetricDisplay() {
        let formatted = TelemetryUnitConverter.formatSpeedLimit(rawOsmValue: 50.0, targetSystem: .metric)
        #expect(formatted == "50 km/h")
    }

    @Test func normalizeSpeedToKmhFromMph() {
        let kmh = TelemetryUnitConverter.normalizeSpeedToKmh(rawValue: 30.0, nativeSystem: .imperial)
        #expect(abs(kmh - 48.2802) < 0.01)
    }

    @Test func formatSpeedKmhAtLondonCoordinate() {
        let london = CLLocationCoordinate2D(latitude: 51.5074, longitude: -0.1278)
        let formatted = TelemetryUnitConverter.formatSpeedKmh(96.0, at: london)
        #expect(formatted == "60 mph")
    }

    @Test func formatSpeedKmhAtOsloCoordinate() {
        let oslo = CLLocationCoordinate2D(latitude: 59.9139, longitude: 10.7522)
        let formatted = TelemetryUnitConverter.formatSpeedKmh(80.0, at: oslo)
        #expect(formatted == "80 km/h")
    }
}
