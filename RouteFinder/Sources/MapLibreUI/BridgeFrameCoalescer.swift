import Foundation

/// Coalesces high-frequency vehicle bridge updates so at most one JS evaluation is in flight
/// with one pending latest-wins update.
@MainActor
final class BridgeFrameCoalescer {
  private var isInFlight = false
  private var pendingState: SimulatedVehicleState?
  private var lastFingerprint: String?

  /// Builds a stable fingerprint from rounded pose and dimension fields for deduplication.
  static func fingerprint(for state: SimulatedVehicleState) -> String {
    let latitude = (state.latitude * 1_000_000).rounded() / 1_000_000
    let longitude = (state.longitude * 1_000_000).rounded() / 1_000_000
    let bearing = (state.bearing * 10).rounded() / 10
    let length = (state.lengthMeters * 100).rounded() / 100
    let width = (state.widthMeters * 100).rounded() / 100
    return "\(latitude),\(longitude),\(bearing),\(length),\(width),\(state.dimensionRevision),\(state.playbackRevision),\(state.renderMode.rawValue),\(state.visible)"
  }

  /// Enqueues a vehicle state update, dispatching immediately or holding as pending.
  func enqueue(
    _ state: SimulatedVehicleState,
    dispatch: @escaping (_ state: SimulatedVehicleState, _ completion: @escaping () -> Void) -> Void
  ) {
    if isInFlight {
      pendingState = state
      return
    }

    let fingerprint = Self.fingerprint(for: state)
    if fingerprint == lastFingerprint {
      return
    }

    isInFlight = true
    lastFingerprint = fingerprint
    dispatch(state) { [weak self] in
      guard let self else { return }
      self.isInFlight = false
      if let pending = self.pendingState {
        self.pendingState = nil
        self.enqueue(pending, dispatch: dispatch)
      }
    }
  }

  /// Clears pending state (e.g. when simulation stops).
  func reset() {
    pendingState = nil
    isInFlight = false
    lastFingerprint = nil
  }
}
