import Contracts
import SwiftUI

/// First-launch sheet asking the user to pick Driver, Dispatcher (Mac), or Office PC.
struct LaunchRoleSheet: View {
    var onSelect: (LaunchRole) -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: RFSpacing.lg) {
                    VStack(alignment: .leading, spacing: RFSpacing.sm) {
                        Text("How will you use RouteFinder?")
                            .font(RFFont.sectionTitle)
                        Text("Pick your role so we can show the right first steps. You can change this later in Settings → Getting started.")
                            .font(RFFont.body)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    ForEach(LaunchRole.allCases, id: \.self) { role in
                        roleCard(role)
                    }
                }
                .padding(RFSpacing.lg)
            }
            .navigationTitle("Getting started")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
        }
        .interactiveDismissDisabled()
    }

    private func roleCard(_ role: LaunchRole) -> some View {
        Button {
            onSelect(role)
        } label: {
            HStack(alignment: .top, spacing: RFSpacing.md) {
                Image(systemName: role.systemImage)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(RFColor.route)
                    .frame(width: 44, height: 44)
                    .background(RFColor.route.opacity(0.15), in: RoundedRectangle(cornerRadius: 12))
                VStack(alignment: .leading, spacing: 4) {
                    Text(role.title)
                        .font(RFFont.summary.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text(role.subtitle)
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
        .accessibilityIdentifier(accessibilityID(for: role))
        .accessibilityAddTraits(.isButton)
    }

    private func accessibilityID(for role: LaunchRole) -> String {
        switch role {
        case .driver:
            return "launchRoleDriver"
        case .dispatcherMac:
            return "launchRoleDispatcher"
        case .officePC:
            return "launchRoleOfficePC"
        }
    }
}
