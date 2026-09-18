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
                Text(advisory.hint)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Advisory only — not a live tariff.")
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
        .accessibilityLabel("\(advisory.name). \(advisory.hint)")
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
}
