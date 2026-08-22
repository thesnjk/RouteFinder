import Contracts
import Foundation

/// Computes live remaining distance and ETA from arc-length progress.
public struct RouteProgressCalculator: Sendable {
    /// Minimum speed floor used when computing ETA in meters per second.
    public static let minimumSpeedMps = 1.0

    /// Creates a route progress calculator.
    public init() {}

    /// Computes a navigation progress snapshot.
    ///
    /// - Parameters:
    ///   - arcLengthMeters: Current arc length along the route spine.
    ///   - totalLengthMeters: Total route length in meters.
    ///   - currentSpeedMps: Current ground speed in meters per second, when available.
    ///   - staticTotalTimeSeconds: Static routing ETA used as fallback proportion.
    ///   - currentManeuverIndex: Index of the upcoming maneuver, when available.
    /// - Returns: Live navigation progress snapshot.
    public func compute(
        arcLengthMeters: Double,
        totalLengthMeters: Double,
        currentSpeedMps: Double?,
        staticTotalTimeSeconds: Double? = nil,
        currentManeuverIndex: Int? = nil
    ) -> NavigationProgressSnapshot {
        let clampedArc = min(max(arcLengthMeters, 0), totalLengthMeters)
        let traveled = clampedArc
        let remaining = max(0, totalLengthMeters - clampedArc)
        let fraction: Double
        if totalLengthMeters > 0 {
            fraction = min(1, max(0, clampedArc / totalLengthMeters))
        } else {
            fraction = 0
        }

        let remainingETA: Double
        if let speed = currentSpeedMps, speed > 0 {
            let effectiveSpeed = max(speed, Self.minimumSpeedMps)
            remainingETA = remaining / effectiveSpeed
        } else if let staticTotal = staticTotalTimeSeconds, totalLengthMeters > 0 {
            remainingETA = (remaining / totalLengthMeters) * staticTotal
        } else {
            remainingETA = 0
        }

        return NavigationProgressSnapshot(
            remainingDistanceMeters: remaining,
            remainingETASeconds: remainingETA,
            traveledDistanceMeters: traveled,
            progressFraction: fraction,
            arcLengthMeters: clampedArc,
            totalLengthMeters: totalLengthMeters,
            currentManeuverIndex: currentManeuverIndex
        )
    }
}
