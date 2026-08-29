import Contracts
import MapLibreUI
import RouteController
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
        .task {
            await viewModel.startFleetDispatchListener()
        }
    }
    #endif

    #if os(iOS)
    @EnvironmentObject private var weatherViewModel: WeatherViewModel
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @AppStorage("iPadPrimaryMode") private var iPadPrimaryMode = "driver"

    private var iOSLayout: some View {
        Group {
            if horizontalSizeClass == .regular, iPadPrimaryMode == "dispatch" {
                DispatchConsoleView(onExitDispatch: { iPadPrimaryMode = "driver" })
            } else {
                NavigationStack {
                    MapWorkspaceView(viewModel: viewModel, mapBridge: mapBridge)
                        .toolbarBackground(.hidden, for: .navigationBar)
                        .toolbar {
                            if horizontalSizeClass == .regular {
                                ToolbarItem(placement: .topBarTrailing) {
                                    Button("Dispatch") {
                                        iPadPrimaryMode = "dispatch"
                                    }
                                }
                            }
                        }
                }
            }
        }
        .onChange(of: weatherViewModel.effectiveCondition) { _, condition in
            viewModel.environmentalContext = condition
            viewModel.refreshSimulationEnvironment()
        }
        .onAppear {
            viewModel.bindVault(session.vault)
            viewModel.seedUITestDemoRouteIfNeeded()
        }
        .task {
            weatherViewModel.startMonitoring()
            viewModel.environmentalContext = weatherViewModel.effectiveCondition
            viewModel.refreshSimulationEnvironment()
            viewModel.seedUITestDemoRouteIfNeeded()
            let skipLocationForUITest = ProcessInfo.processInfo.arguments.contains("UITEST_SKIP_AUTH")
            if !skipLocationForUITest {
                await viewModel.startLocationServicesIfNeeded()
            }
            await viewModel.startFleetDispatchListener()
        }
    }
    #endif

}

/// Map workspace that observes simulation engine updates for the vehicle marker.
private struct MapWorkspaceView: View {
    @Bindable var viewModel: RouteViewModel
    @ObservedObject private var simulationEngine: RouteSimulationEngine
    @ObservedObject private var mapBridge: MapViewControllerBridge
    @State private var showProductOnboarding = !NavigationWorkspaceSettings.loadHasSeenProductOnboarding()
    #if os(iOS)
    @State private var showVehicleModeOnboarding = false
    #endif
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
        ZStack {
            MapRouteView(
                coordinates: viewModel.routeCoordinates,
                encodedPolyline: viewModel.routeEncodedPolyline,
                encodedPolylinePrecision: viewModel.routeEncodedPolylinePrecision,
                routeCumulativeLengths: viewModel.routeCumulativeLengths,
                pins: viewModel.displayMapPins,
                hazardsGeoJSON: viewModel.hazardOverlayJSON,
                simulatedVehicle: viewModel.liveMapVehicleState(),
                interactionMode: viewModel.interactionMode,
                initialRegion: viewModel.mapRegion,
                styleURL: viewModel.mapStyleURL,
                labelLanguage: viewModel.preferredMapLabelLanguage,
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
                },
                onUseOnlineMap: {
                    Task {
                        await viewModel.fallbackToOnlineMapStyle()
                    }
                }
            )

            MapFirstShell(viewModel: viewModel, onOpenProfile: onOpenProfile, onOpenSettings: onOpenSettings)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(MapCanvasBackdrop.color)
        .ignoresSafeArea(edges: .all)
        .overlay(alignment: .bottom) {
            if case .setPin = viewModel.interactionMode {
                MapPinToolbar(viewModel: viewModel)
                    .padding(.bottom, RFSpacing.lg + 120)
            }
        }
        .sheet(isPresented: $showProductOnboarding, onDismiss: markProductOnboardingSeen) {
            ProductOnboardingSheet(
                requireLiabilityAcceptance: !NavigationWorkspaceSettings.loadHasAcceptedRoutingLiability()
            )
        }
        #if os(iOS)
        .sheet(isPresented: $showVehicleModeOnboarding) {
            VehicleModeOnboardingSheet { passengerCar in
                viewModel.applyVehicleModeFromOnboarding(passengerCar: passengerCar)
                showVehicleModeOnboarding = false
            }
        }
        .onAppear {
            if NavigationWorkspaceSettings.loadHasSeenProductOnboarding(),
               !NavigationWorkspaceSettings.loadHasCompletedVehicleModeOnboarding() {
                showVehicleModeOnboarding = true
            }
        }
        #endif
    }

    private func markProductOnboardingSeen() {
        let liabilityAccepted = NavigationWorkspaceSettings.loadHasAcceptedRoutingLiability()
        let previouslySeen = NavigationWorkspaceSettings.loadHasSeenProductOnboarding()
        // First-launch liability gate: do not clear the sheet if Terms were never accepted.
        if !liabilityAccepted, !previouslySeen {
            showProductOnboarding = true
            return
        }
        NavigationWorkspaceSettings.saveHasSeenProductOnboarding(true)
        #if os(iOS)
        if !NavigationWorkspaceSettings.loadHasCompletedVehicleModeOnboarding() {
            showVehicleModeOnboarding = true
        }
        #endif
    }
}
