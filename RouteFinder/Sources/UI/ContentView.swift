import Contracts
import MapLibreUI
import SwiftUI

#if os(macOS)
import AppKit
#endif

/// Root content view with full-screen map and map-first controls.
public struct ContentView: View {
    @Bindable var session: SessionController
    @State private var viewModel: RouteViewModel
    @StateObject private var mapBridge = MapViewControllerBridge()

    public init(session: SessionController) {
        self.session = session
        _viewModel = State(initialValue: RouteViewModel(vault: session.vault))
    }

    /// Convenience initializer for previews / iOS entry without auth.
    public init() {
        let session = SessionController()
        self.session = session
        _viewModel = State(initialValue: RouteViewModel(vault: nil))
    }

    public var body: some View {
        #if os(macOS)
        macOSLayout
        #else
        iOSLayout
        #endif
    }

    #if os(macOS)
    @State private var isSettingsPresented = false

    private var macOSLayout: some View {
        NavigationSplitView {
            VehicleProfileManager(viewModel: viewModel)
                .navigationSplitViewColumnWidth(min: 300, ideal: 320, max: 380)
        } detail: {
            MapWorkspaceView(
                viewModel: viewModel,
                mapBridge: mapBridge,
                onOpenSettings: { isSettingsPresented = true }
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
        .background(MacWindowConfigurator())
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Menu {
                    if let email = session.currentEmail {
                        Text(email)
                    }
                    Button("Log Out") {
                        session.logout()
                    }
                    Button("Delete Account…", role: .destructive) {
                        session.deleteAccount()
                    }
                } label: {
                    Label("Account", systemImage: "person.crop.circle")
                }
            }
        }
        .sheet(isPresented: $isSettingsPresented) {
            SettingsSheet(viewModel: viewModel)
        }
        .onChange(of: isSettingsPresented) { _, isPresented in
            if isPresented {
                MacAppActivation.activateForTextInput()
            }
        }
        .onAppear {
            viewModel.bindVault(session.vault)
        }
    }
    #endif

    #if os(iOS)
    @EnvironmentObject private var weatherViewModel: WeatherViewModel

    private var iOSLayout: some View {
        MapWorkspaceView(viewModel: viewModel, mapBridge: mapBridge)
            .onChange(of: weatherViewModel.effectiveCondition) { _, condition in
                viewModel.environmentalContext = condition
                viewModel.refreshSimulationEnvironment()
            }
            .task {
                viewModel.environmentalContext = weatherViewModel.effectiveCondition
                viewModel.refreshSimulationEnvironment()
                await viewModel.startLocationServicesIfNeeded()
            }
    }
    #endif

}

/// Map workspace that observes simulation engine updates for the vehicle marker.
private struct MapWorkspaceView: View {
    @Bindable var viewModel: RouteViewModel
    @ObservedObject private var simulationEngine: RouteSimulationEngine
    @ObservedObject private var mapBridge: MapViewControllerBridge
    var onOpenProfile: () -> Void
    var onOpenSettings: () -> Void

    init(
        viewModel: RouteViewModel,
        mapBridge: MapViewControllerBridge,
        onOpenProfile: @escaping () -> Void = {},
        onOpenSettings: @escaping () -> Void = {}
    ) {
        self.viewModel = viewModel
        self._simulationEngine = ObservedObject(wrappedValue: viewModel.simulationEngine)
        self._mapBridge = ObservedObject(wrappedValue: mapBridge)
        self.onOpenProfile = onOpenProfile
        self.onOpenSettings = onOpenSettings
        viewModel.mapBridge = mapBridge
    }

    var body: some View {
        let _ = simulationEngine.playbackRevision

        ZStack {
            MapRouteView(
                coordinates: viewModel.routeCoordinates,
                encodedPolyline: viewModel.routeEncodedPolyline,
                encodedPolylinePrecision: viewModel.routeEncodedPolylinePrecision,
                routeCumulativeLengths: viewModel.routeCumulativeLengths,
                pins: viewModel.mapPins,
                hazardsGeoJSON: viewModel.hazardOverlayJSON,
                simulatedVehicle: simulatedVehicleState,
                interactionMode: viewModel.interactionMode,
                initialRegion: viewModel.mapRegion,
                mapBridge: mapBridge,
                onMapClick: { coordinate in
                    Task {
                        await viewModel.handleMapClick(
                            at: Coordinate(latitude: coordinate.latitude, longitude: coordinate.longitude)
                        )
                    }
                },
                onContextAction: { action, coordinate in
                    Task {
                        await viewModel.handleContextAction(
                            action,
                            at: Coordinate(latitude: coordinate.latitude, longitude: coordinate.longitude)
                        )
                    }
                },
                onRegionChange: { center in
                    viewModel.updateMapViewport(center: center)
                }
            )

            MapFirstShell(viewModel: viewModel, onOpenProfile: onOpenProfile, onOpenSettings: onOpenSettings)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(alignment: .bottom) {
            if case .setPin = viewModel.interactionMode {
                MapPinToolbar(viewModel: viewModel)
                    .padding(.bottom, RFSpacing.lg + 120)
            }
        }
    }

    private var simulatedVehicleState: SimulatedVehicleState? {
        guard !simulationEngine.isRunning,
              let coordinate = simulationEngine.currentCoordinate else {
            return nil
        }
        let profile = viewModel.resolvedSpecificationProfile ?? mapBridge.activeSpecificationProfile
        let length = profile?.lengthMeters ?? simulationEngine.vehicleLengthMeters
        let width = profile?.widthMeters ?? simulationEngine.vehicleWidthMeters
        let footprint = mapBridge.updateVehicleSimulationLayer(
            currentLocation: coordinate,
            headingDegrees: simulationEngine.currentBearing,
            activeProfile: profile,
            lengthMeters: length,
            widthMeters: width
        )
        return SimulatedVehicleState(
            latitude: coordinate.latitude,
            longitude: coordinate.longitude,
            bearing: simulationEngine.currentBearing,
            visible: true,
            lengthMeters: length,
            widthMeters: width,
            playbackRevision: simulationEngine.playbackRevision,
            dimensionRevision: simulationEngine.dimensionRevision,
            renderMode: mapBridge.renderMode(for: mapBridge.currentMapZoom),
            footprintCoordinates: footprint
        )
    }
}
