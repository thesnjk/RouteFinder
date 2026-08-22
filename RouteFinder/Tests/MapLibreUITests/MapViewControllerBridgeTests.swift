import MapLibreUI
import Testing

struct MapViewControllerBridgeTests {
    @Test @MainActor func renderMode_switchesAtLODThreshold() {
        let bridge = MapViewControllerBridge()

        #expect(bridge.renderMode(for: 15.9) == .icon)
        #expect(bridge.renderMode(for: 16.0) == .polygon)
        #expect(bridge.renderMode(for: 17.5) == .polygon)
    }
}
