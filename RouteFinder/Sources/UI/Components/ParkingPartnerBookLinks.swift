import Contracts
import SwiftUI

/// Partner redirect CTAs to book / find truck parking (TRAVIS + SNAP).
///
/// Opens the public partner sites via ``ParkingPartnerLinks``. Booking and fees
/// stay between the driver and the parking operator — RouteFinder does not take payment.
struct ParkingPartnerBookLinks: View {
    let latitude: Double
    let longitude: Double
    var label: String? = nil
    /// When true, shows the short partner-disclaimer under the links.
    var showsDisclaimer: Bool = true
    /// Compact caption style for dense POI rows; larger for the layby banner.
    var compact: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 2 : 4) {
            HStack(spacing: compact ? 8 : RFSpacing.sm) {
                Link(
                    "Book (TRAVIS)",
                    destination: ParkingPartnerLinks.travisURL(
                        latitude: latitude,
                        longitude: longitude,
                        label: label
                    )
                )
                .accessibilityIdentifier("parkingBookTravis")

                Link(
                    "Book (SNAP)",
                    destination: ParkingPartnerLinks.snapURL(
                        latitude: latitude,
                        longitude: longitude,
                        label: label
                    )
                )
                .accessibilityIdentifier("parkingBookSnap")
            }
            .font(compact ? .caption2 : RFFont.caption)
            .controlSize(.small)

            if showsDisclaimer {
                Text("Opens partner site — booking and fees are between you and the operator.")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }
}
