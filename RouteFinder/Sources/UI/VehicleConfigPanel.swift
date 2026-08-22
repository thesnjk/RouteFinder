import SwiftUI

/// Vehicle dimensional constraint inputs.
public struct VehicleConfigPanel: View {
    @Bindable var viewModel: RouteViewModel

    public init(viewModel: RouteViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Vehicle")
                .font(.headline)
                .vibrancyLabel()

            HStack {
                TextField("Height (m)", text: $viewModel.vehicleHeight)
                    .textFieldStyle(.roundedBorder)
                TextField("Weight (t)", text: $viewModel.vehicleWeight)
                    .textFieldStyle(.roundedBorder)
            }

            HStack {
                TextField("Width (m)", text: $viewModel.vehicleWidth)
                    .textFieldStyle(.roundedBorder)
                TextField("Length (m)", text: $viewModel.vehicleLength)
                    .textFieldStyle(.roundedBorder)
            }
        }
    }
}
