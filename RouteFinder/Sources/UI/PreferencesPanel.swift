import Contracts
import SwiftUI

/// Optimization mode and avoid toggles.
public struct PreferencesPanel: View {
    @Bindable var viewModel: RouteViewModel

    public init(viewModel: RouteViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Preferences")
                .font(.headline)
                .vibrancyLabel()

            Picker("Mode", selection: $viewModel.optimizationMode) {
                ForEach(OptimizationMode.allCases, id: \.self) { mode in
                    Text(mode.rawValue.capitalized).tag(mode)
                }
            }
            .pickerStyle(.menu)

            Toggle("Avoid Tolls", isOn: $viewModel.avoidTolls)
            Toggle("Avoid Ferries", isOn: $viewModel.avoidFerries)
            Toggle("Avoid Tunnels", isOn: $viewModel.avoidTunnels)
            Toggle("Avoid non-compliant LEZ / CAZ", isOn: $viewModel.avoidNonCompliantLEZ)
                .onChange(of: viewModel.avoidNonCompliantLEZ) { _, _ in
                    viewModel.scheduleVehicleWorkspacePersist()
                }
            Toggle("Hurry Mode", isOn: $viewModel.hurryMode)
        }
    }
}
