import Charts
import Contracts
import SwiftUI

/// Post-route InsurTech telematics dashboard comparing kinetic vs static ETA.
public struct PredictiveTelemetryReportView: View {
    let report: PredictiveTelemetryReport

    /// Creates a predictive telemetry report view.
    public init(report: PredictiveTelemetryReport) {
        self.report = report
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: RFSpacing.sm) {
            headerRow
            efficiencyGauge
            etaComparisonChart
            eventMetricsGrid
            if report.estimatedPremiumSavingsGBP > 0 {
                savingsCapsule
            }
        }
        .padding(RFSpacing.sm)
        .controlSheetStyle()
    }

    private var headerRow: some View {
        HStack {
            Text("Predictive Telemetry")
                .font(RFFont.sectionTitle)
            Spacer()
            efficiencyBadge
        }
    }

    private var efficiencyBadge: some View {
        Text(String(format: "%.0f", report.brakeWearKineticEfficiencyIndex))
            .font(RFFont.summary.monospacedDigit())
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(efficiencyColor.opacity(0.2))
            .foregroundStyle(efficiencyColor)
            .clipShape(Capsule())
    }

    private var efficiencyColor: Color {
        let index = report.brakeWearKineticEfficiencyIndex
        if index >= 80 { return .green }
        if index >= 60 { return .orange }
        return .red
    }

    private var efficiencyGauge: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Brake Wear & Kinetic Fleet Efficiency Index")
                .font(RFFont.caption)
                .foregroundStyle(.secondary)

            Gauge(value: report.brakeWearKineticEfficiencyIndex, in: 0...100) {
                Text("Efficiency")
            } currentValueLabel: {
                Text(String(format: "%.0f", report.brakeWearKineticEfficiencyIndex))
                    .font(RFFont.caption.monospacedDigit())
            }
            .gaugeStyle(.accessoryLinear)
            .tint(efficiencyColor)
        }
    }

    private var etaComparisonChart: some View {
        VStack(alignment: .leading, spacing: RFSpacing.xs) {
            Text("ETA Comparison")
                .font(RFFont.caption)
                .foregroundStyle(.secondary)

            Chart {
                BarMark(
                    x: .value("Source", "Static Web"),
                    y: .value("Minutes", report.staticWebETASeconds / 60)
                )
                .foregroundStyle(Color.secondary.opacity(0.6))

                BarMark(
                    x: .value("Source", "Kinetic Physics"),
                    y: .value("Minutes", report.kineticPhysicsETASeconds / 60)
                )
                .foregroundStyle(RFColor.route)
            }
            .chartYAxisLabel("Minutes")
            .frame(height: 120)
        }
    }

    private var eventMetricsGrid: some View {
        LazyVGrid(
            columns: [GridItem(.flexible()), GridItem(.flexible())],
            spacing: RFSpacing.sm
        ) {
            metricCell(title: "Hard Decels", value: "\(report.hardDecelEventCount)", icon: "exclamationmark.triangle.fill")
            metricCell(title: "Brake Fade", value: "\(report.brakeFadeRiskEventCount)", icon: "thermometer.high")
            metricCell(title: "Lateral G", value: "\(report.lateralGViolationCount)", icon: "arrow.turn.up.right")
            metricCell(title: "Tire Slip", value: "\(report.tireSlipEventCount)", icon: "circle.dotted")
        }
    }

    private func metricCell(title: String, value: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(title, systemImage: icon)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(RFFont.summary.monospacedDigit())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(RFSpacing.sm)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
    }

    private var savingsCapsule: some View {
        HStack {
            Image(systemName: "sterlingsign.circle.fill")
                .foregroundStyle(.green)
            Text("Est. premium savings: £\(formattedSavings)/yr")
                .font(RFFont.caption.weight(.semibold))
                .foregroundStyle(.green)
        }
        .padding(.horizontal, RFSpacing.sm)
        .padding(.vertical, RFSpacing.xs)
        .background(Color.green.opacity(0.15), in: Capsule())
    }

    private var formattedSavings: String {
        let number = NSDecimalNumber(decimal: report.estimatedPremiumSavingsGBP)
        return String(format: "%.0f", number.doubleValue)
    }
}
