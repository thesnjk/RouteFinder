import SwiftUI

/// Floating map toolbar for pin placement modes.
struct MapPinToolbar: View {
    @Bindable var viewModel: RouteViewModel

    var body: some View {
        HStack(spacing: RFSpacing.sm) {
            pinButton("Set Start", waypointID: viewModel.originWaypoint.id, icon: "circle.fill", color: RFColor.start)
            pinButton("Set End", waypointID: viewModel.destinationWaypoint.id, icon: "mappin.circle.fill", color: RFColor.end)
            addStopButton

            if case .setPin = viewModel.interactionMode {
                Button("Done") {
                    viewModel.cancelPinMode()
                }
                .modifier(GlassButton())
            }
        }
        .padding(.horizontal, RFSpacing.md)
        .padding(.vertical, RFSpacing.sm)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().strokeBorder(.white.opacity(0.2), lineWidth: 0.5))
        .depthShadow()
    }

    private var addStopButton: some View {
        let pendingViaID = viewModel.viaWaypoints.last?.id
        let isActive: Bool = {
            if case .setPin(let id) = viewModel.interactionMode,
               viewModel.viaWaypoints.contains(where: { $0.id == id }) {
                return true
            }
            return false
        }()

        return Button {
            if isActive {
                viewModel.cancelPinMode()
            } else {
                viewModel.addWaypoint()
                let insertIndex = viewModel.routeWaypoints.count - 2
                viewModel.beginPinMode(for: viewModel.routeWaypoints[insertIndex].id)
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "plus.circle.fill")
                    .foregroundStyle(RFColor.waypoint)
                Text("Add Stop")
                    .font(.caption.weight(.medium))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(isActive ? RFColor.waypoint.opacity(0.2) : .clear, in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(pendingViaID?.uuidString ?? "add-stop")
    }

    private func pinButton(_ title: String, waypointID: UUID, icon: String, color: Color) -> some View {
        let isActive = viewModel.interactionMode == .setPin(waypointID)

        return Button {
            if isActive {
                viewModel.cancelPinMode()
            } else {
                viewModel.beginPinMode(for: waypointID)
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .foregroundStyle(color)
                Text(title)
                    .font(.caption.weight(.medium))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(isActive ? color.opacity(0.2) : .clear, in: Capsule())
        }
        .buttonStyle(.plain)
    }
}
