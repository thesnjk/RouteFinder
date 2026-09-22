import Contracts
import SwiftUI

/// Post–vehicle-mode sheet offering fleet pairing or solo ORS setup for drivers.
struct DriverNextStepsSheet: View {
    var onPairFleet: () -> Void
    var onSolo: () -> Void
    var onSkip: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: RFSpacing.lg) {
                    VStack(alignment: .leading, spacing: RFSpacing.sm) {
                        Text("Connect to your fleet?")
                            .font(RFFont.sectionTitle)
                        Text("Fleet pilots pair with the office Mac so trips arrive over Wi‑Fi and routing uses the operator-paid ORS proxy — no personal HeiGIT key needed.")
                            .font(RFFont.body)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    nextStepCard(
                        title: "Pair with fleet",
                        subtitle: "Discover the office server, test connection, scan vehicle QR",
                        icon: "qrcode.viewfinder",
                        accessibilityIdentifier: "driverNextStepsPairFleet",
                        action: onPairFleet
                    )

                    nextStepCard(
                        title: "Solo driver",
                        subtitle: "Add a HeiGIT API key in Settings for search and routing without a fleet server",
                        icon: "key.fill",
                        accessibilityIdentifier: "driverNextStepsSolo",
                        action: onSolo
                    )

                    Button("Skip for now", action: onSkip)
                        .buttonStyle(.borderless)
                        .frame(maxWidth: .infinity)
                        .accessibilityIdentifier("driverNextStepsSkip")
                }
                .padding(RFSpacing.lg)
            }
            .navigationTitle("Driver setup")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
        }
        .accessibilityIdentifier("driverNextStepsSheet")
        .interactiveDismissDisabled()
    }

    private func nextStepCard(
        title: String,
        subtitle: String,
        icon: String,
        accessibilityIdentifier: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: RFSpacing.md) {
                Image(systemName: icon)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(RFColor.route)
                    .frame(width: 44, height: 44)
                    .background(RFColor.route.opacity(0.15), in: RoundedRectangle(cornerRadius: 12))
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
