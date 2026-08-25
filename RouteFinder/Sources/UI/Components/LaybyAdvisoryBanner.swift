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

            VStack(alignment: .leading, spacing: 2) {
                Text("Layby in \(formattedDistance)")
                    .font(RFFont.sectionTitle)
                Text(advisory.stop.label)
                    .font(RFFont.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
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
        .accessibilityLabel("Layby in \(formattedDistance), \(advisory.stop.label)")
    }

    private var formattedDistance: String {
        let meters = advisory.distanceRemainingMeters
        if meters >= 1000 {
            return String(format: "%.1f km", meters / 1000)
        }
        return String(format: "%.0f m", meters)
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
