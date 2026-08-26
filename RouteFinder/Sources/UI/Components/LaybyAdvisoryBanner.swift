import Contracts
import SwiftUI

/// Banner announcing an upcoming layby with a driver feedback action.
struct LaybyAdvisoryBanner: View {
    let advisory: LaybyAdvisory
    var onLaybyFull: () -> Void

    var body: some View {
        HStack(spacing: RFSpacing.md) {
            Image(systemName: "parkingsign.circle.fill")
                .font(.title3)
                .foregroundStyle(.tint)

            VStack(alignment: .leading, spacing: 4) {
                Text(primaryLine)
                    .font(RFFont.sectionTitle)
                    .fixedSize(horizontal: false, vertical: true)
                Text(advisory.stop.label)
                    .font(RFFont.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                if !detailLine.isEmpty {
                    Text(detailLine)
                        .font(RFFont.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if advisory.isAdvisory {
                    Text("Advisory — digital tachograph remains the legal record.")
                        .font(RFFont.caption)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer(minLength: RFSpacing.sm)

            Button("Layby full") {
                onLaybyFull()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(RFSpacing.md)
        .controlSheetStyle()
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilitySummary)
    }

    private var primaryLine: String {
        "You will need to stop at \(advisory.stop.label) in \(formattedETA) / \(formattedDistance)"
    }

    private var detailLine: String {
        var parts: [String] = []
        if let opensAt = advisory.breakWindowOpensAt {
            parts.append("break window opens at \(formattedTime(opensAt))")
        }
        parts.append("occupancy prior: \(advisory.occupancyPrior.displayLabel)")
        return parts.joined(separator: "; ")
    }

    private var formattedDistance: String {
        let meters = advisory.distanceRemainingMeters
        if meters >= 1000 {
            return String(format: "%.0f mi", meters / 1609.34)
        }
        return String(format: "%.0f m", meters)
    }

    private var formattedETA: String {
        guard let seconds = advisory.estimatedArrivalSeconds, seconds > 0 else {
            return "—"
        }
        let minutes = Int((seconds / 60).rounded())
        if minutes >= 60 {
            let hours = minutes / 60
            let remainder = minutes % 60
            return remainder == 0 ? "~\(hours) h" : "~\(hours) h \(remainder) min"
        }
        return "~\(max(1, minutes)) min"
    }

    private func formattedTime(_ date: Date) -> String {
        advisoryTimeFormatter.string(from: date)
    }

    private var accessibilitySummary: String {
        var summary = primaryLine
        if !detailLine.isEmpty {
            summary += ". \(detailLine)"
        }
        if advisory.isAdvisory {
            summary += ". Advisory only."
        }
        return summary
    }

    private var advisoryTimeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter
    }
}

/// Compact HUD banner for live kinetic advisories during simulation or navigation.
struct LiveKineticAdvisoryBanner: View {
    let text: String

    var body: some View {
        HStack(spacing: RFSpacing.sm) {
            Image(systemName: "flame.fill")
                .font(.body.weight(.semibold))
                .foregroundStyle(RFColor.hazard)
            Text(text)
                .font(RFFont.caption.weight(.semibold))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, RFSpacing.md)
        .padding(.vertical, RFSpacing.sm)
        .controlSheetStyle()
        .accessibilityLabel(text)
    }
}
