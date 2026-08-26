import SwiftUI

/// Native fleet dispatch console: trip form + map/status split view.
public struct DispatchConsoleView: View {
    @State private var viewModel = DispatchViewModel()

    public init() {}

    public var body: some View {
        NavigationSplitView {
            DispatchTripFormView(viewModel: viewModel)
                .navigationSplitViewColumnWidth(min: 320, ideal: 380, max: 440)
        } detail: {
            VStack(spacing: 0) {
                DispatchMapDetailView(trip: viewModel.activeTrip, draft: viewModel.draft)
                    .frame(minHeight: 280)
                DispatchStatusPanel(trip: viewModel.activeTrip)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            #if os(macOS)
            .background(Color(nsColor: .windowBackgroundColor))
            #endif
        }
        .task {
            await viewModel.refreshCatalog()
            viewModel.startPolling()
        }
        .onDisappear {
            viewModel.stopPolling()
        }
    }
}
