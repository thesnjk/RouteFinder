import Contracts
import Foundation

/// Post-route analytical service generating predictive telemetry reports.
public enum PredictiveTelemetryService {
    /// Weight for hard deceleration penalty.
    public static let hardDecelWeight = 0.35

    /// Weight for thermal brake fade penalty.
    public static let thermalFadeWeight = 0.30

    /// Weight for lateral G excess penalty.
    public static let lateralGWeight = 0.20

    /// Weight for tire slip event penalty.
    public static let tireSlipWeight = 0.15

    /// Minimum efficiency index for insurance savings display.
    public static let insuranceThresholdIndex = 70.0

    /// Default HGV fleet annual premium baseline in GBP.
    public static let defaultAnnualPremiumGBP: Decimal = 2400

    /// Generates a predictive telemetry report from simulation data.
    public static func generateReport(
        staticWebETASeconds: TimeInterval,
        kineticPhysicsETASeconds: TimeInterval,
        events: [SimulationEvent],
        thermalFadeIntegral: Double,
        lateralGExcessSeconds: TimeInterval,
        peakBrakeFadeRisk: BrakeFadeRisk?,
        vehicleWeightTonnes: Double?
    ) -> PredictiveTelemetryReport {
        let hardDecelCount = events.filter { $0.kind == .hardDeceleration }.count
        let brakeFadeCount = events.filter { $0.kind == .brakeFade }.count
        let lateralGCount = events.filter { $0.kind == .lateralGViolation }.count
        let tireSlipCount = events.filter { $0.kind == .tireSlip }.count

        let normalizedHardDecels = min(Double(hardDecelCount) / 10.0, 1.0) * 100.0
        let normalizedThermal = min(thermalFadeIntegral / TopographicalGradientEngine.criticalThermalLoadJoules, 1.0) * 100.0
        let normalizedLateralG = min(lateralGExcessSeconds / 30.0, 1.0) * 100.0
        let normalizedTireSlip = min(Double(tireSlipCount) / 8.0, 1.0) * 100.0

        let penalty = hardDecelWeight * normalizedHardDecels
            + thermalFadeWeight * normalizedThermal
            + lateralGWeight * normalizedLateralG
            + tireSlipWeight * normalizedTireSlip

        let index = max(0, min(100, 100.0 - penalty))

        let premiumBaseline = annualPremium(for: vehicleWeightTonnes)
        let savings: Decimal
        if index >= insuranceThresholdIndex {
            let complianceMultiplier = Decimal(string: "0.12") ?? 0.12
            let indexFactor = Decimal(index - insuranceThresholdIndex) / 100
            savings = premiumBaseline * indexFactor * complianceMultiplier
        } else {
            savings = 0
        }

        return PredictiveTelemetryReport(
            staticWebETASeconds: staticWebETASeconds,
            kineticPhysicsETASeconds: kineticPhysicsETASeconds,
            brakeWearKineticEfficiencyIndex: index,
            estimatedPremiumSavingsGBP: savings,
            hardDecelEventCount: hardDecelCount,
            brakeFadeRiskEventCount: brakeFadeCount,
            lateralGViolationCount: lateralGCount,
            tireSlipEventCount: tireSlipCount,
            brakeFadeRiskState: peakBrakeFadeRisk,
            events: events
        )
    }

    private static func annualPremium(for weightTonnes: Double?) -> Decimal {
        let weight = weightTonnes ?? 44.0
        if weight >= 20 {
            return defaultAnnualPremiumGBP
        }
        return Decimal(string: "1800") ?? 1800
    }
}
