import Foundation
import os

/// os_signpost instrumentation for simulation loop performance profiling in Instruments.
enum SimulationInstrumentation {
  private static let log = OSLog(subsystem: "com.routefinder.simulation", category: "Performance")

  static func beginPhysicsTick() -> OSSignpostID {
    let id = OSSignpostID(log: log)
    os_signpost(.begin, log: log, name: "PhysicsTick", signpostID: id)
    return id
  }

  static func endPhysicsTick(_ id: OSSignpostID) {
    os_signpost(.end, log: log, name: "PhysicsTick", signpostID: id)
  }

  static func beginDisplayFrame() -> OSSignpostID {
    let id = OSSignpostID(log: log)
    os_signpost(.begin, log: log, name: "DisplayFrame", signpostID: id)
    return id
  }

  static func endDisplayFrame(_ id: OSSignpostID) {
    os_signpost(.end, log: log, name: "DisplayFrame", signpostID: id)
  }

  static func beginBridgeEval() -> OSSignpostID {
    let id = OSSignpostID(log: log)
    os_signpost(.begin, log: log, name: "BridgeEval", signpostID: id)
    return id
  }

  static func endBridgeEval(_ id: OSSignpostID) {
    os_signpost(.end, log: log, name: "BridgeEval", signpostID: id)
  }
}
