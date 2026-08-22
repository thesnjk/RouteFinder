import Foundation

/// Hashable geographic key for coordinate-indexed scheduling constraints.
public struct GeoCoordinateKey: Hashable, Codable, Sendable, Equatable {
    /// Latitude quantized to micro-degrees for stable dictionary keys.
    public let latitudeMicroDegrees: Int64
    /// Longitude quantized to micro-degrees for stable dictionary keys.
    public let longitudeMicroDegrees: Int64

    private static let microDegreesPerDegree: Double = 1_000_000.0

    /// Creates a coordinate key from a routing coordinate.
    public init(_ coordinate: RoutingCoordinate) {
        latitudeMicroDegrees = Self.quantize(coordinate.latitude)
        longitudeMicroDegrees = Self.quantize(coordinate.longitude)
    }

    /// Creates a coordinate key from explicit latitude and longitude.
    public init(latitude: Double, longitude: Double) {
        latitudeMicroDegrees = Self.quantize(latitude)
        longitudeMicroDegrees = Self.quantize(longitude)
    }

    /// Latitude in decimal degrees.
    public var latitude: Double {
        Double(latitudeMicroDegrees) / Self.microDegreesPerDegree
    }

    /// Longitude in decimal degrees.
    public var longitude: Double {
        Double(longitudeMicroDegrees) / Self.microDegreesPerDegree
    }

    /// Routing coordinate representation.
    public var routingCoordinate: RoutingCoordinate {
        RoutingCoordinate(latitude: latitude, longitude: longitude)
    }

    /// Returns whether this key matches another coordinate within a distance tolerance.
    public func matches(
        _ coordinate: RoutingCoordinate,
        epsilonMeters: Double = 1.0
    ) -> Bool {
        let distance = Self.haversineMeters(
            latitude: latitude,
            longitude: longitude,
            otherLatitude: coordinate.latitude,
            otherLongitude: coordinate.longitude
        )
        return distance <= epsilonMeters
    }

    private static func quantize(_ value: Double) -> Int64 {
        Int64((value * microDegreesPerDegree).rounded())
    }

    private static func haversineMeters(
        latitude: Double,
        longitude: Double,
        otherLatitude: Double,
        otherLongitude: Double
    ) -> Double {
        let earthRadius = 6_371_000.0
        let lat1 = latitude * .pi / 180.0
        let lat2 = otherLatitude * .pi / 180.0
        let deltaLat = (otherLatitude - latitude) * .pi / 180.0
        let deltaLon = (otherLongitude - longitude) * .pi / 180.0
        let sinDLat = sin(deltaLat / 2.0)
        let sinDLon = sin(deltaLon / 2.0)
        let h = sinDLat * sinDLat + cos(lat1) * cos(lat2) * sinDLon * sinDLon
        return 2.0 * earthRadius * atan2(sqrt(h), sqrt(max(0.0, 1.0 - h)))
    }
}
