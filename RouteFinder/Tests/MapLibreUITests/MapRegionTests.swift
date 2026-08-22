import CoreLocation
import MapLibreUI
import Testing

struct MapRegionTests {
    @Test func zoomLevel_usesLongitudeSpanForWideRoutes() {
        let wideRegion = MapRegion(
            center: CLLocationCoordinate2D(latitude: 52.5, longitude: 0.5),
            latitudeDelta: 0.2,
            longitudeDelta: 1.4
        )
        let latOnlyZoom = log2(360 / 0.2) - 1
        #expect(wideRegion.zoomLevel < latOnlyZoom)
    }

    @Test func zoomLevel_matchesForSquareRegion() {
        let region = MapRegion(
            center: CLLocationCoordinate2D(latitude: 51.5, longitude: -0.1),
            latitudeDelta: 0.4,
            longitudeDelta: 0.4
        )
        let expected = max(1, min(18, log2(360 / 0.4) - 1))
        #expect(region.zoomLevel == expected)
    }

    @Test func zoomLevel_clampsToValidRange() {
        let tightRegion = MapRegion(
            center: CLLocationCoordinate2D(latitude: 51.5, longitude: -0.1),
            latitudeDelta: 0.00001,
            longitudeDelta: 0.00001
        )
        #expect(tightRegion.zoomLevel <= 18)
        #expect(tightRegion.zoomLevel >= 1)

        let wideRegion = MapRegion(
            center: CLLocationCoordinate2D(latitude: 51.5, longitude: -0.1),
            latitudeDelta: 100,
            longitudeDelta: 100
        )
        #expect(wideRegion.zoomLevel >= 1)
    }
}
