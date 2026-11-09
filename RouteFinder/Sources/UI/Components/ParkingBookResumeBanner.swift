import Contracts
import SwiftUI

/// Shown after the driver returns from a TRAVIS / SNAP book redirect (app-side resume).
struct ParkingBookResumeBanner: View {
    let pending: PendingParkingBookReturn
    var onKeepNavigating: () -> Void
    var onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: RFSpacing.sm) {
            Text(pending.resumeMessage)
                .font(RFFont.caption.weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)
            if let tier = pending.tier {
                ParkingAvailabilityBadge(tier: tier)
            }
            HStack(spacing: RFSpacing.sm) {
                Button("Keep nav", action: onKeepNavigating)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                Button("Dismiss", action: onDismiss)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
            Text("Partner booking stays on their site — RouteFinder does not take payment.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(RFSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .controlSheetStyle()
        .accessibilityIdentifier("parkingBookResumeBanner")
    }
}

/// Compact sheet to book an ahead parking / layby map stop.
struct ParkingMapBookSheet: View {
    let stop: PendingParkingBookReturn
    var onBookOpened: (ParkingBookPartner) -> Void
    var onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: RFSpacing.md) {
            HStack {
                Text(stop.label)
                    .font(RFFont.sectionTitle)
                Spacer()
                if let tier = stop.tier {
                    ParkingAvailabilityBadge(tier: tier)
                }
            }
            ParkingPartnerBookLinks(
                latitude: stop.latitude,
                longitude: stop.longitude,
                label: stop.label,
                tier: stop.tier,
                stopId: stop.id,
                showsDisclaimer: true,
                compact: false,
                onBookOpened: onBookOpened
            )
            Button("Close", action: onClose)
                .buttonStyle(.bordered)
                .controlSize(.small)
        }
        .padding(RFSpacing.md)
        .controlSheetStyle()
        .accessibilityIdentifier("parkingMapBookSheet")
    }
}
