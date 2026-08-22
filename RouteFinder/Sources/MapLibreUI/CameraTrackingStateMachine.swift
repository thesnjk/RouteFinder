import Contracts
import Foundation

/// Three-mode camera tracking state machine for navigation map follow.
@MainActor
public final class CameraTrackingStateMachine {
    /// Current camera tracking mode.
    public private(set) var mode: CameraTrackingMode = .lockNorth
    /// Pitch applied in heading-lock mode.
    public var headingLockPitchDegrees: Double = 45
    /// Low-pass smoothing factor for bearing rotation (0–1).
    public var bearingSmoothingFactor: Double = 0.15
    /// Smoothed bearing used for heading-lock camera rotation.
    public private(set) var smoothedBearing: Double = 0

    /// Creates a camera tracking state machine.
    public init(initialMode: CameraTrackingMode = .lockNorth) {
        mode = initialMode
    }

    /// Transitions to a new camera mode.
    public func transition(to newMode: CameraTrackingMode) {
        mode = newMode
        if newMode == .lockNorth {
            smoothedBearing = 0
        }
    }

    /// Handles user-initiated map pan or zoom by releasing camera lock.
    public func userDidPanOrZoom() {
        mode = .freePan
    }

    /// Re-enables camera lock, optionally restoring a specific mode.
    public func resumeTracking(preferredMode: CameraTrackingMode = .lockNorth) {
        mode = preferredMode
        if preferredMode == .lockNorth {
            smoothedBearing = 0
        }
    }

    /// Updates smoothed bearing from a new vehicle bearing sample.
    public func updateBearing(_ bearing: Double) {
        let normalized = bearing.truncatingRemainder(dividingBy: 360)
        if mode != .lockHeading {
            smoothedBearing = normalized
            return
        }
        let delta = shortestBearingDelta(from: smoothedBearing, to: normalized)
        smoothedBearing = (smoothedBearing + delta * bearingSmoothingFactor)
            .truncatingRemainder(dividingBy: 360)
        if smoothedBearing < 0 { smoothedBearing += 360 }
    }

    /// Returns the bearing to apply to the map for the current mode.
    public func mapBearing(forVehicleBearing vehicleBearing: Double) -> Double? {
        switch mode {
        case .freePan:
            return nil
        case .lockNorth:
            return 0
        case .lockHeading:
            updateBearing(vehicleBearing)
            return smoothedBearing
        }
    }

    /// Returns the pitch to apply to the map for the current mode.
    public func mapPitch() -> Double? {
        switch mode {
        case .freePan, .lockNorth:
            return 0
        case .lockHeading:
            return headingLockPitchDegrees
        }
    }

    private func shortestBearingDelta(from: Double, to: Double) -> Double {
        var delta = to - from
        while delta > 180 { delta -= 360 }
        while delta < -180 { delta += 360 }
        return delta
    }
}
