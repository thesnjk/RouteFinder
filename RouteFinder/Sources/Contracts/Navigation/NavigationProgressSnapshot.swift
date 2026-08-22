import Foundation

/// Live navigation progress metrics for UI and CarPlay consumers.
public struct NavigationProgressSnapshot: Sendable, Equatable {
    /// Distance remaining along the route spine in meters.
    public let remainingDistanceMeters: Double
    /// Estimated time remaining in seconds.
    public let remainingETASeconds: Double
    /// Distance traveled along the route spine in meters.
    public let traveledDistanceMeters: Double
    /// Normalized progress fraction in `[0, 1]`.
    public let progressFraction: Double
    /// Current arc length along the route spine in meters.
    public let arcLengthMeters: Double
    /// Total route length in meters.
    public let totalLengthMeters: Double
    /// Index of the current upcoming maneuver, when available.
    public let currentManeuverIndex: Int?

    /// Creates a navigation progress snapshot.
    public init(
        remainingDistanceMeters: Double,
        remainingETASeconds: Double,
        traveledDistanceMeters: Double,
        progressFraction: Double,
        arcLengthMeters: Double,
        totalLengthMeters: Double,
        currentManeuverIndex: Int? = nil
    ) {
        self.remainingDistanceMeters = remainingDistanceMeters
        self.remainingETASeconds = remainingETASeconds
        self.traveledDistanceMeters = traveledDistanceMeters
        self.progressFraction = progressFraction
        self.arcLengthMeters = arcLengthMeters
        self.totalLengthMeters = totalLengthMeters
        self.currentManeuverIndex = currentManeuverIndex
    }
}
