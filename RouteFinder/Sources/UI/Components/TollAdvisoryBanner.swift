import Contracts
import SwiftUI

/// Compact advisory banner for an upcoming UK toll / crossing.
struct TollAdvisoryBanner: View {
    let advisory: UKTollAdvisory
    let distanceMeters: Double?

    var body: some View {
        HStack(spacing: RFSpacing.sm) {
            Image(systemName: "dollarsign.circle.fill")
                .foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 2) {
                Text(titleLine)
                    .font(RFFont.caption.weight(.semibold))
                    .fixedSize(horizontal: false, vertical: true)
                if let cost = advisory.indicativeCostLabel {
                    Text(cost)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.orange)
                }
                Text(advisory.hint)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Advisory only — check operator; not a live tariff.")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            Spacer(minLength: 0)
            if let url = advisory.infoURL {
                Link(destination: url) {
                    Image(systemName: "arrow.up.right.square")
                }
                .accessibilityLabel("Open toll operator info")
            }
        }
        .padding(.horizontal, RFSpacing.md)
        .padding(.vertical, RFSpacing.sm)
        .controlSheetStyle()
        .accessibilityLabel(accessibilitySummary)
    }

    private var titleLine: String {
        if let distanceMeters {
            if distanceMeters >= 1000 {
                return String(format: "%@ · %.1f km", advisory.name, distanceMeters / 1000)
            }
            return "\(advisory.name) · \(Int(distanceMeters)) m"
        }
        return advisory.name
    }

    private var accessibilitySummary: String {
        var parts = [advisory.name]
        if let cost = advisory.indicativeCostLabel {
            parts.append(cost)
        }
        parts.append(advisory.hint)
        return parts.joined(separator: ". ")
    }
}
