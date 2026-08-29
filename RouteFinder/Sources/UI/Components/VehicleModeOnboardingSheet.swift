#if os(iOS)
import Contracts
import SwiftUI

/// First-launch sheet asking the driver to choose Car or HGV routing.
struct VehicleModeOnboardingSheet: View {
    var onSelect: (Bool) -> Void

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: RFSpacing.lg) {
                VStack(alignment: .leading, spacing: RFSpacing.sm) {
                    Text("How will you drive?")
                        .font(RFFont.sectionTitle)
                    Text("RouteFinder uses this to pick roads and vehicle limits. You can change it later in Settings or the map menu.")
                        .font(RFFont.body)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                vehicleCard(
                    title: "Car",
                    subtitle: "Passenger vehicle — similar to Waze or Apple Maps",
                    icon: "car.fill",
                    tint: RFColor.route,
                    accessibilityIdentifier: "vehicleModeCarButton"
                ) {
                    onSelect(true)
                }

                vehicleCard(
                    title: "HGV",
                    subtitle: "UK artic preset — height, weight, and layby-aware routing",
                    icon: "truck.box.fill",
                    tint: .orange,
                    accessibilityIdentifier: "vehicleModeHGVButton"
                ) {
                    onSelect(false)
                }

                Spacer(minLength: 0)
            }
            .padding(RFSpacing.lg)
            .navigationTitle("Vehicle type")
            .navigationBarTitleDisplayMode(.inline)
        }
        .interactiveDismissDisabled()
    }

    private func vehicleCard(
        title: String,
        subtitle: String,
        icon: String,
        tint: Color,
        accessibilityIdentifier: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: RFSpacing.md) {
                Image(systemName: icon)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(tint)
                    .frame(width: 44, height: 44)
                    .background(tint.opacity(0.15), in: RoundedRectangle(cornerRadius: 12))
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(RFFont.summary.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text(subtitle)
                        .font(RFFont.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(RFSpacing.md)
            .glassPanel(cornerRadius: 16)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(accessibilityIdentifier)
    }
}
#endif
