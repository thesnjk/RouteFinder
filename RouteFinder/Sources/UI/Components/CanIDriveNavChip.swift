import Contracts
import SwiftUI

/// Compact Can-I-drive chip for map chrome (advisory — not legal VU).
struct CanIDriveNavChip: View {
    let status: CanIDriveStatus
    @State private var isExpanded = false

    var body: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                isExpanded.toggle()
            }
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: RFSpacing.sm) {
                    Image(systemName: status.canDrive ? "checkmark.circle.fill" : "pause.circle.fill")
                        .foregroundStyle(status.canDrive ? RFColor.start : RFColor.hazard)
                    Text(status.canDrive ? "Can drive" : "Break")
                        .font(RFFont.caption.weight(.semibold))
                    if status.usesPartnerAdvisory {
                        Text("Partner")
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                }
                if isExpanded {
                    Text(status.reason)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.leading)
                }
            }
            .padding(.horizontal, RFSpacing.md)
            .padding(.vertical, RFSpacing.sm)
            .frame(maxWidth: .infinity, alignment: .leading)
            .controlSheetStyle()
        }
        .buttonStyle(.plain)
        .accessibilityLabel(status.canDrive ? "Can drive now" : "Break required")
        .accessibilityHint("Shows advisory remaining drive detail. Not a legal tachograph.")
    }
}
