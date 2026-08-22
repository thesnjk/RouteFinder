import CoreLocation
import Foundation

/// Platform-agnostic map viewport for MapLibre rendering.
public struct MapRegion: Sendable {
    public var center: CLLocationCoordinate2D
    public var latitudeDelta: Double
    public var longitudeDelta: Double

    public init(center: CLLocationCoordinate2D, latitudeDelta: Double, longitudeDelta: Double) {
        self.center = center
        self.latitudeDelta = latitudeDelta
        self.longitudeDelta = longitudeDelta
    }

    /// Approximate MapLibre zoom level for this region span.
    public var zoomLevel: Double {
        let latZoom = log2(360 / max(latitudeDelta, 0.0001))
        let lonZoom = log2(360 / max(longitudeDelta, 0.0001))
        return max(1, min(18, min(latZoom, lonZoom) - 1))
    }
}

extension MapRegion: Equatable {
    public static func == (lhs: MapRegion, rhs: MapRegion) -> Bool {
        lhs.center.latitude == rhs.center.latitude
            && lhs.center.longitude == rhs.center.longitude
            && lhs.latitudeDelta == rhs.latitudeDelta
            && lhs.longitudeDelta == rhs.longitudeDelta
    }
}
