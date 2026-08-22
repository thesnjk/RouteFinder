import SwiftUI

/// Algorithm selection control.
public struct AlgorithmPicker: View {
    @Bindable var viewModel: RouteViewModel

    public init(viewModel: RouteViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Algorithm")
                .font(.headline)
                .vibrancyLabel()

            Picker("Algorithm", selection: $viewModel.useAStar) {
                Text("A*").tag(true)
                Text("Dijkstra").tag(false)
            }
            .pickerStyle(.segmented)
        }
    }
}
