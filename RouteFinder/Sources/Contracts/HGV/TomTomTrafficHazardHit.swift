import Foundation

/// A TomTom live-traffic standstill or road-closure hit projected ahead on the route.
public struct TomTomTrafficHazardHit: Sendable, Hashable, Codable, Equatable, Identifiable {
    public let id: String
    public let latitude: Double
    public let longitude: Double
    public let arcLengthAlongRouteMeters: Double
    public let isRoadClosed: Bool

    /// Creates a TomTom traffic hazard hit.
    public init(
        id: String,
        latitude: Double,
        longitude: Double,
        arcLengthAlongRouteMeters: Double,
        isRoadClosed: Bool
    ) {
        self.id = id
        self.latitude = latitude
        self.longitude = longitude
        self.arcLengthAlongRouteMeters = arcLengthAlongRouteMeters
        self.isRoadClosed = isRoadClosed
    }
}
