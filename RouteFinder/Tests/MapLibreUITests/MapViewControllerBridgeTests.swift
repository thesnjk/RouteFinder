import CoreLocation
import MapLibreUI
import Testing

struct MapViewControllerBridgeTests {
    @Test @MainActor func renderMode_switchesAtLODThreshold() {
        let bridge = MapViewControllerBridge()
        bridge.isTrackingVehicle = false

        #expect(bridge.renderMode(for: 15.9) == .icon)
        #expect(bridge.renderMode(for: 16.0) == .polygon)
        #expect(bridge.renderMode(for: 17.5) == .polygon)

        bridge.isTrackingVehicle = true
        #expect(bridge.renderMode(for: 15.0) == .polygon)
    }

    @Test func cameraFollowCenter_offsetsForwardHalfLength() {
        let rearAxle = CLLocationCoordinate2D(latitude: 52.6300, longitude: 1.2970)
        let center = MapViewControllerBridge.cameraFollowCenter(
            rearAxle: rearAxle,
            bearingDegrees: 0,
            lengthMeters: 16.5
        )
        // Bearing 0 = north → latitude increases by ~half length.
        #expect(center.latitude > rearAxle.latitude)
        #expect(abs(center.longitude - rearAxle.longitude) < 0.00001)
        let metersNorth = (center.latitude - rearAxle.latitude) * 111_320.0
        #expect(abs(metersNorth - 8.25) < 0.5)
    }

    @Test @MainActor func defaultTrackingZoom_isPulledBackForHGVFeel() {
        let bridge = MapViewControllerBridge()
        #expect(bridge.trackingZoomLevel == 15.0)
    }
}
