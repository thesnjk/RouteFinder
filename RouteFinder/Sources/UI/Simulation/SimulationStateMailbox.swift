import Contracts
import CostModel
import Foundation
import os

/// Compact physics pose written by the simulation actor and read synchronously on the main thread.
public struct SimulationDisplaySnapshot: Sendable, Equatable {
  /// Ring buffer of recent physics poses for frame interpolation.
  public let poseSnapshots: [SimulationPoseSnapshot]
  /// Distance along the route in meters.
  public let arcLengthMeters: Double
  /// Vehicle heading in degrees clockwise from north.
  public let bearingDegrees: Double
  /// Longitudinal speed in meters per second.
  public let speedMps: Double
  /// Monotonically increasing revision for bridge deduplication.
  public let revision: UInt64

  /// Creates a display snapshot.
  public init(
    poseSnapshots: [SimulationPoseSnapshot],
    arcLengthMeters: Double,
    bearingDegrees: Double,
    speedMps: Double,
    revision: UInt64
  ) {
    self.poseSnapshots = poseSnapshots
    self.arcLengthMeters = arcLengthMeters
    self.bearingDegrees = bearingDegrees
    self.speedMps = speedMps
    self.revision = revision
  }
}

/// Published simulation feedback mirrored from the physics actor for UI binding.
public struct SimulationUIState: Sendable, Equatable {
  public let speedKmh: Double
  public let activeLegalSpeedLimitKmh: Double?
  public let speedLimitSource: SpeedLimitSource
  public let velocityCapReason: VelocityCapReason
  public let isBrakingWarning: Bool
  public let isPausedForSignal: Bool
  public let brakeFadeRisk: BrakeFadeRisk?
  public let topographyState: TopographyGradientState?
  public let currentKineticStress: SegmentKineticStress?
  public let simulationElapsedSeconds: TimeInterval
  public let isRunning: Bool

  /// Creates UI state from physics outputs.
  public init(
    speedKmh: Double,
    activeLegalSpeedLimitKmh: Double? = nil,
    speedLimitSource: SpeedLimitSource = .regionalDefault,
    velocityCapReason: VelocityCapReason = .legal,
    isBrakingWarning: Bool,
    isPausedForSignal: Bool,
    brakeFadeRisk: BrakeFadeRisk?,
    topographyState: TopographyGradientState?,
    currentKineticStress: SegmentKineticStress?,
    simulationElapsedSeconds: TimeInterval,
    isRunning: Bool
  ) {
    self.speedKmh = speedKmh
    self.activeLegalSpeedLimitKmh = activeLegalSpeedLimitKmh
    self.speedLimitSource = speedLimitSource
    self.velocityCapReason = velocityCapReason
    self.isBrakingWarning = isBrakingWarning
    self.isPausedForSignal = isPausedForSignal
    self.brakeFadeRisk = brakeFadeRisk
    self.topographyState = topographyState
    self.currentKineticStress = currentKineticStress
    self.simulationElapsedSeconds = simulationElapsedSeconds
    self.isRunning = isRunning
  }
}

/// Lock-free handoff of the latest physics frame between the actor and the main thread.
public final class SimulationStateMailbox: @unchecked Sendable {
  private let lock = OSAllocatedUnfairLock()
  private var displaySnapshot: SimulationDisplaySnapshot?
  private var uiState: SimulationUIState?

  /// Creates an empty mailbox.
  public init() {}

  /// Writes the latest display snapshot from the physics actor.
  public func writeDisplay(_ snapshot: SimulationDisplaySnapshot) {
    lock.withLock {
      displaySnapshot = snapshot
    }
  }

  /// Writes the latest UI feedback state from the physics actor.
  public func writeUI(_ state: SimulationUIState) {
    lock.withLock {
      uiState = state
    }
  }

  /// Reads the latest display snapshot without blocking on actor work.
  public func readDisplay() -> SimulationDisplaySnapshot? {
    lock.withLock { displaySnapshot }
  }

  /// Reads the latest UI feedback state without blocking on actor work.
  public func readUI() -> SimulationUIState? {
    lock.withLock { uiState }
  }

  /// Clears all cached state.
  public func reset() {
    lock.withLock {
      displaySnapshot = nil
      uiState = nil
    }
  }
}
