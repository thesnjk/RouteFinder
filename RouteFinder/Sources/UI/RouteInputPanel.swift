import Contracts
import SwiftUI

/// Route origin, destination, and waypoint input panel.
public struct RouteInputPanel: View {
    @Bindable var viewModel: RouteViewModel

    public init(viewModel: RouteViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Route")
                .font(.headline)
                .vibrancyLabel()

            ForEach($viewModel.routeWaypoints) { $waypoint in
                HStack {
                    TextField(fieldLabel(for: waypoint.role), text: $waypoint.rawText)
                        .textFieldStyle(.roundedBorder)

                    if waypoint.role == .via {
                        Button("Remove") {
                            viewModel.removeWaypoint(id: waypoint.id)
                        }
                        .buttonStyle(.borderless)
                    }
                }
                .id(waypoint.id)
            }

            HStack {
                Button("Add Stop") {
                    viewModel.addWaypoint()
                }
                .glassButton()

                Button(viewModel.isCalculating ? "Calculating…" : "Find Route") {
                    Task { await viewModel.calculateRoute() }
                }
                .glassButton()
                .disabled(viewModel.isCalculating)
            }
        }
    }

    private func fieldLabel(for role: RouteWaypoint.Role) -> String {
        switch role {
        case .origin: "From (node ID)"
        case .destination: "To (node ID)"
        case .via: "Waypoint"
        }
    }
}
