import SwiftUI

/// Glassmorphic modal for route calculation failures.
struct RouteFailureSheet: View {
    let presentation: RouteFailurePresentation
    let onDismiss: () -> Void

    private var iconName: String {
        switch presentation.kind {
        case .hgvInfeasible: "truck.box.fill"
        case .routeBlocked: "exclamationmark.octagon.fill"
        case .coverage: "map.fill"
        case .snapFailed: "mappin.slash"
        case .generic: "exclamationmark.triangle.fill"
        }
    }

    private var iconColor: Color {
        switch presentation.kind {
        case .hgvInfeasible: RFColor.hazard
        case .routeBlocked: RFColor.hazard
        case .coverage: RFColor.route
        case .snapFailed: .orange
        case .generic: .red
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: RFSpacing.md) {
            HStack(alignment: .top, spacing: RFSpacing.sm) {
                Image(systemName: iconName)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(iconColor)

                VStack(alignment: .leading, spacing: RFSpacing.sm) {
                    Text(presentation.title)
                        .font(RFFont.sectionTitle)

                    Text(presentation.message)
                        .font(RFFont.body)
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)

                    if let detail = presentation.detail, !detail.isEmpty {
                        Text(detail)
                            .font(RFFont.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            HStack {
                Spacer()
                Button("Dismiss", action: onDismiss)
                    .modifier(GlassButton())
            }
        }
        .padding(RFSpacing.lg)
        .frame(minWidth: 340)
        .controlSheetStyle()
        .padding(RFSpacing.md)
    }
}
