import SwiftUI

/// Native fleet dispatch console: trip form + map/status split view.
public struct DispatchConsoleView: View {
    @State private var viewModel = DispatchViewModel()
    private var onExitDispatch: (() -> Void)?

    /// Creates the dispatch console, optionally with a callback to return to driver mode on iPad.
    public init(onExitDispatch: (() -> Void)? = nil) {
        self.onExitDispatch = onExitDispatch
    }

    public var body: some View {
        NavigationSplitView {
            DispatchTripFormView(viewModel: viewModel)
                .navigationSplitViewColumnWidth(min: 320, ideal: 380, max: 440)
        } detail: {
            VStack(spacing: 0) {
                DispatchMapDetailView(
                    trip: viewModel.activeTrip,
                    draft: viewModel.draft,
                    previewCoordinates: viewModel.previewCoordinates,
                    isPreviewLoading: viewModel.isPreviewLoading
                )
                .frame(minHeight: 280)
                DispatchStatusPanel(
                    trip: viewModel.activeTrip,
                    vehicleLabel: viewModel.selectedVehicleLabel,
                    previewCoordinates: viewModel.previewCoordinates,
                    telematicsImportBatch: viewModel.telematicsImportBatch
                )
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            #if os(macOS)
            .background(Color(nsColor: .windowBackgroundColor))
            #endif
        }
        .overlay(alignment: .top) {
            if let toast = viewModel.toastMessage {
                Text(toast)
                    .font(RFFont.caption.weight(.semibold))
                    .padding(.horizontal, RFSpacing.md)
                    .padding(.vertical, RFSpacing.sm)
                    .controlSheetStyle()
                    .padding(.top, RFSpacing.md)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.easeOut(duration: 0.2), value: viewModel.toastMessage)
        .navigationTitle("Dispatch")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            if let onExitDispatch {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Driver") {
                        onExitDispatch()
                    }
                }
            }
            ToolbarItem(placement: .automatic) {
                fleetHealthPill
            }
        }
        .task {
            await viewModel.refreshCatalog()
            await viewModel.reloadTelematicsImport()
            viewModel.startPolling()
            viewModel.startHealthPolling()
        }
        .onDisappear {
            viewModel.stopPolling()
            viewModel.stopHealthPolling()
        }
    }

    @ViewBuilder
    private var fleetHealthPill: some View {
        let isLocal = viewModel.fleetServerModeLabel == "Local disk"
        let ok = isLocal || viewModel.fleetServerHealthOk == true
        let label: String = {
            if isLocal {
                return "Local disk"
            }
            if viewModel.fleetServerHealthOk == true {
                if let version = viewModel.fleetServerVersion {
                    return "Connected · v\(version)"
                }
                return "Connected"
            }
            if viewModel.fleetServerHealthOk == false {
                return "Offline"
            }
            return "Checking…"
        }()
        Text(label)
            .font(RFFont.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .foregroundStyle(ok ? Color.green : Color.red)
            .controlSheetStyle()
    }
}
