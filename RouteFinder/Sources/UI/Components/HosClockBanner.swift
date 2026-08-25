import Contracts
import SwiftUI

/// Compact glass HUD for the advisory EU hours-of-service clock.
struct HosClockBanner: View {
    let snapshot: HosClockSnapshot

    var body: some View {
        HStack(spacing: RFSpacing.sm) {
            Image(systemName: "clock.badge.exclamationmark")
                .font(.body.weight(.semibold))
                .foregroundStyle(RFColor.hazard)

            VStack(alignment: .leading, spacing: 2) {
                Text("HOS · \(snapshot.mode.displayName)")
                    .font(RFFont.caption.weight(.semibold))
                    .foregroundStyle(.primary)
                Text("Drive left \(formatted(snapshot.remainingContinuousDriveSeconds)) · day \(formatted(snapshot.remainingDailyDriveSeconds))")
                    .font(RFFont.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, RFSpacing.md)
        .padding(.vertical, RFSpacing.sm)
        .glassPanel(cornerRadius: 12)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "Hours of service, \(snapshot.mode.displayName), continuous drive remaining \(formatted(snapshot.remainingContinuousDriveSeconds))"
        )
    }

    private func formatted(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds.rounded()))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }
}
