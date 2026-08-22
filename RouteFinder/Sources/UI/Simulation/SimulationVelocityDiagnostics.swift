import Contracts
import Foundation
import os

/// Throttled velocity-cap diagnostics for simulation debugging.
enum SimulationVelocityDiagnostics {
    private static let log = OSLog(subsystem: "com.routefinder.simulation", category: "VelocityCap")
    nonisolated(unsafe) private static var lastLogInstant: ContinuousClock.Instant?
    private static let minLogIntervalSeconds: Double = 1.0

    /// UserDefaults key for enabling velocity cap logging outside debug builds.
    static let diagnosticsEnabledKey = "SimulationVelocityDiagnosticsEnabled"

    /// Returns true when velocity cap diagnostics should be emitted.
    static var isEnabled: Bool {
        #if DEBUG
        return true
        #else
        return UserDefaults.standard.bool(forKey: diagnosticsEnabledKey)
        #endif
    }

    /// Logs binding contributors when throttling interval has elapsed.
    static func logVelocityCap(
        arcLength: Double,
        vLegal: Double,
        legalLimitKmh: Double,
        limitSource: SpeedLimitSource,
        measurementSystem: RegionalMeasurementSystem,
        vCurve: Double,
        vCruise: Double,
        vSignal: Double,
        vTarget: Double,
        simulationElapsedSeconds: TimeInterval
    ) {
        guard isEnabled else { return }

        let now = ContinuousClock.now
        if let lastLogInstant {
            let elapsed = Double(lastLogInstant.duration(to: now).components.seconds)
                + Double(lastLogInstant.duration(to: now).components.attoseconds) / 1e18
            if elapsed < minLogIntervalSeconds { return }
        }
        Self.lastLogInstant = now

        let binding: String
        if vTarget == vSignal && vSignal < vLegal && vSignal < vCurve && vSignal < vCruise {
            binding = "vSignal"
        } else if abs(vTarget - vCurve) < 0.01 {
            binding = "vCurve"
        } else if abs(vTarget - vLegal) < 0.01 {
            binding = "vLegal"
        } else if abs(vTarget - vCruise) < 0.01 {
            binding = "vCruise"
        } else {
            binding = "composite"
        }

        let message = """
        arcLength=\(String(format: "%.1f", arcLength)) t=\(String(format: "%.1f", simulationElapsedSeconds))s \
        vLegal=\(formatMps(vLegal)) (\(String(format: "%.1f", legalLimitKmh)) km/h, source=\(limitSource), region=\(measurementSystem)) \
        vCurve=\(formatMps(vCurve)) vCruise=\(formatMps(vCruise)) vSignal=\(formatMps(vSignal)) \
        vTarget=\(formatMps(vTarget)) binding=\(binding)
        """
        os_log("%{public}@", log: log, type: .debug, message)
    }

    private static func formatMps(_ value: Double) -> String {
        guard value.isFinite else { return "∞" }
        let kmh = value * 3.6
        return String(format: "%.1f m/s (%.1f km/h)", value, kmh)
    }
}
