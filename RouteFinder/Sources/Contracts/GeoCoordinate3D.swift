import Foundation

/// A geographic coordinate with optional elevation, safe for cross-platform route sync.
public struct GeoCoordinate3D: Sendable, Hashable, Codable {
    /// Latitude in decimal degrees.
    public let latitude: Double
    /// Longitude in decimal degrees.
    public let longitude: Double
    /// Elevation in meters above sea level, when available.
    public let elevationMeters: Double?

    /// Creates a 3D geographic coordinate.
    public init(latitude: Double, longitude: Double, elevationMeters: Double? = nil) {
        self.latitude = latitude
        self.longitude = longitude
        self.elevationMeters = elevationMeters
    }

    /// Creates from a 2D coordinate with optional elevation.
    public init(_ coordinate: Coordinate, elevationMeters: Double? = nil) {
        self.latitude = coordinate.latitude
        self.longitude = coordinate.longitude
        self.elevationMeters = elevationMeters ?? coordinate.elevationMeters
    }

    /// Converts to the shared 2D/3D coordinate type.
    public var coordinate: Coordinate {
        Coordinate(latitude: latitude, longitude: longitude, elevationMeters: elevationMeters)
    }
}

extension Coordinate {
    /// 3D view of this coordinate including elevation when present.
    public var geoCoordinate3D: GeoCoordinate3D {
        GeoCoordinate3D(latitude: latitude, longitude: longitude, elevationMeters: elevationMeters)
    }
}
