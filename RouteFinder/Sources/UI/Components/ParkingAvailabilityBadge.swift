import Contracts
import SwiftUI

/// Compact tinted availability chip for parking / layby rows (ample / limited / full).
struct ParkingAvailabilityBadge: View {
    let tier: ParkingAvailabilityTier

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: tier.systemImageName)
                .font(.caption2.weight(.semibold))
            Text(tier.displayLabel)
                .font(.caption2.weight(.semibold))
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(tint.opacity(0.14), in: Capsule())
        .overlay(Capsule().strokeBorder(tint.opacity(0.35), lineWidth: 0.5))
        .accessibilityLabel(tier.accessibilityLabel)
    }

    private var tint: Color {
        switch tier {
        case .ample: return .green
        case .limited: return .orange
        case .full: return RFColor.hazard
        }
    }
}
