import Contracts
import Foundation

/// Interpolated display pose between two physics snapshots.
public struct InterpolatedVehiclePose: Sendable, Equatable {
    /// Map coordinate including interpolated elevation when available.
    public let coordinate: Coordinate
    /// Interpolated heading in degrees clockwise from north.
    public let bearingDegrees: Double
    /// Interpolated arc length along the route spine in meters.
    public let arcLengthMeters: Double

    /// Creates an interpolated vehicle pose.
    public init(coordinate: Coordinate, bearingDegrees: Double, arcLengthMeters: Double = 0) {
        self.coordinate = coordinate
        self.bearingDegrees = bearingDegrees
        self.arcLengthMeters = arcLengthMeters
    }
}

/// Frame-rate-independent linear interpolation between simulation pose snapshots.
public struct VehiclePoseInterpolator: Sendable {
    private let sampler: RouteArcLengthSampler

    /// Creates an interpolator that samples coordinates along the route arc length.
    public init(sampler: RouteArcLengthSampler) {
        self.sampler = sampler
    }

    /// Interpolates pose at `displayTime` between two physics snapshots.
    public func interpolate(
        from earlier: SimulationPoseSnapshot,
        to later: SimulationPoseSnapshot,
        at displayTime: ContinuousClock.Instant,
        displaySimulationTimeSeconds: Double? = nil
    ) -> InterpolatedVehiclePose {
        let alpha = interpolationAlpha(
            from: earlier,
            to: later,
            at: displayTime,
            displaySimulationTimeSeconds: displaySimulationTimeSeconds
        )
        let arcLength = earlier.arcLengthMeters
            + (later.arcLengthMeters - earlier.arcLengthMeters) * alpha
        let bearing = Self.angleLerp(
            from: earlier.bearingDegrees,
            to: later.bearingDegrees,
            t: alpha
        )
        return InterpolatedVehiclePose(
            coordinate: sampler.coordinate(at: arcLength),
            bearingDegrees: bearing,
            arcLengthMeters: arcLength
        )
    }

    /// Returns pose from the latest snapshot when only one sample exists.
    public func pose(from snapshot: SimulationPoseSnapshot) -> InterpolatedVehiclePose {
        InterpolatedVehiclePose(
            coordinate: sampler.coordinate(at: snapshot.arcLengthMeters),
            bearingDegrees: snapshot.bearingDegrees,
            arcLengthMeters: snapshot.arcLengthMeters
        )
    }

    private func interpolationAlpha(
        from earlier: SimulationPoseSnapshot,
        to later: SimulationPoseSnapshot,
        at time: ContinuousClock.Instant,
        displaySimulationTimeSeconds: Double?
    ) -> Double {
        if let displaySimulationTimeSeconds {
            let totalSim = later.simulationTimeSeconds - earlier.simulationTimeSeconds
            if totalSim > 1e-6 {
                let elapsedSim = displaySimulationTimeSeconds - earlier.simulationTimeSeconds
                return min(1, max(0, elapsedSim / totalSim))
            }
        }

        let total = earlier.wallClockTime.duration(to: later.wallClockTime)
        let elapsed = earlier.wallClockTime.duration(to: time)
        let totalSeconds = Self.seconds(from: total)
        guard totalSeconds > 1e-6 else { return 1 }
        let elapsedSeconds = Self.seconds(from: elapsed)
        return min(1, max(0, elapsedSeconds / totalSeconds))
    }

    private static func seconds(from duration: Duration) -> Double {
        let components = duration.components
        return Double(components.seconds)
            + Double(components.attoseconds) / 1_000_000_000_000_000_000
    }

    /// Shortest-path linear interpolation for compass bearings in degrees.
    public static func angleLerp(from: Double, to: Double, t: Double) -> Double {
        var delta = (to - from).truncatingRemainder(dividingBy: 360)
        if delta > 180 { delta -= 360 }
        if delta < -180 { delta += 360 }
        var result = from + delta * t
        if result < 0 { result += 360 }
        if result >= 360 { result -= 360 }
        return result
    }
}
