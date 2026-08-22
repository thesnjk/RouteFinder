import Foundation
import os

/// os_signpost instrumentation for map bridge performance profiling in Instruments.
enum SimulationBridgeInstrumentation {
  private static let log = OSLog(subsystem: "com.routefinder.simulation", category: "MapBridge")

  static func beginBridgeEval() -> OSSignpostID {
    let id = OSSignpostID(log: log)
    os_signpost(.begin, log: log, name: "BridgeEval", signpostID: id)
    return id
  }

  static func endBridgeEval(_ id: OSSignpostID) {
    os_signpost(.end, log: log, name: "BridgeEval", signpostID: id)
  }
}
