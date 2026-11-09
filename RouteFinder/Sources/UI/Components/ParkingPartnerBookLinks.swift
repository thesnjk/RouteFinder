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
    /// Availability tier drives caption and TRAVIS emphasis (never hides redirect).
    var tier: ParkingAvailabilityTier? = nil
    /// Stable id for pending return stash (defaults to label or coordinate key).
    var stopId: String? = nil
    /// When true, shows the short partner-disclaimer under the links.
    var showsDisclaimer: Bool = true
    /// Compact caption style for dense POI rows; larger for the layby banner.
    var compact: Bool = false
    /// Called just before the system opens the partner URL (stash pending return).
    var onBookOpened: ((ParkingBookPartner) -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: compact ? 2 : 4) {
            HStack(spacing: compact ? 8 : RFSpacing.sm) {
                bookLink(
                    title: "Book (TRAVIS)",
                    partner: .travis,
                    url: ParkingPartnerLinks.travisURL(
                        latitude: latitude,
                        longitude: longitude,
                        label: label
                    ),
                    emphasized: ParkingBookCTACopy.emphasizesTravis(for: tier),
                    accessibilityId: "parkingBookTravis"
                )

                bookLink(
                    title: "Book (SNAP)",
                    partner: .snap,
                    url: ParkingPartnerLinks.snapURL(
                        latitude: latitude,
                        longitude: longitude,
                        label: label
                    ),
                    emphasized: false,
                    accessibilityId: "parkingBookSnap"
                )
            }
            .font(compact ? .caption2 : RFFont.caption)
            .controlSize(.small)

            if let caption = ParkingBookCTACopy.caption(for: tier) {
                Text(caption)
                    .font(.caption2)
                    .foregroundStyle(tier == .full ? RFColor.hazard : .secondary)
            }

            if showsDisclaimer {
                Text("Opens partner site — booking and fees are between you and the operator.")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    @ViewBuilder
    private func bookLink(
        title: String,
        partner: ParkingBookPartner,
        url: URL,
        emphasized: Bool,
        accessibilityId: String
    ) -> some View {
        let secondary = ParkingBookCTACopy.usesSecondaryBookStyle(for: tier)
        Link(title, destination: url)
            .simultaneousGesture(
                TapGesture().onEnded {
                    onBookOpened?(partner)
                }
            )
            .fontWeight(emphasized && !secondary ? .semibold : .regular)
            .foregroundStyle(secondary ? .secondary : (emphasized ? RFColor.route : .primary))
            .accessibilityIdentifier(accessibilityId)
    }
}
