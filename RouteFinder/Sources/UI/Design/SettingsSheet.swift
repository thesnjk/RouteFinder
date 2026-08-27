import Contracts
import RouteController
import SwiftUI

/// Settings sheet for algorithm, vehicle, avoidance, and HeiGIT API configuration.
struct SettingsSheet: View {
    @Bindable var viewModel: RouteViewModel
    @Environment(\.dismiss) private var dismiss
    #if os(iOS)
    @EnvironmentObject private var weatherViewModel: WeatherViewModel
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    #endif
    @State private var showInspectionSheet = false
    @State private var showDispatchConsole = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: RFSpacing.lg) {
                    algorithmSection
                    vehicleSection
                    if viewModel.isHGVMode {
                        TachoAdvisorySettingsSection(viewModel: viewModel)
                        inspectionSection
                    }
                    avoidanceSection
                    environmentSection
                    navigationSection
                    offlineRoutingSection
                    offlineMapSection
                    orsAPIKeySection
                    openWeatherAPIKeySection
                    regCheckUsernameSection
                    dvlaAPIKeySection
                    tomTomAPIKeySection
                    fleetSection
                    OSMAttributionFooter()
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(RFSpacing.lg)
                .padding(.bottom, RFSpacing.xl)
            }
            .navigationTitle("Settings")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showInspectionSheet) {
                InspectionWalkaroundSheet(viewModel: viewModel)
            }
            .sheet(isPresented: $showDispatchConsole) {
                DispatchConsoleView()
            }
        }
        #if os(macOS)
        .frame(width: macSheetSize.width, height: macSheetSize.height)
        .onAppear {
            MacAppActivation.activateForTextInput()
        }
        #endif
    }

    #if os(macOS)
    private var macSheetSize: CGSize { MacSheetMetrics.fittedSize() }
    #endif

    private var algorithmSection: some View {
        VStack(alignment: .leading, spacing: RFSpacing.sm) {
            Text("Algorithm")
                .font(RFFont.sectionTitle)
            Picker("Algorithm", selection: $viewModel.useAStar) {
                Text("A*").tag(true)
                Text("Dijkstra").tag(false)
            }
            .pickerStyle(.segmented)
        }
    }

    private var vehicleSection: some View {
        VStack(alignment: .leading, spacing: RFSpacing.sm) {
            Text("Vehicle Profile")
                .font(RFFont.sectionTitle)

            Toggle("HGV / Truck Mode", isOn: $viewModel.isHGVMode)
                .tint(RFColor.hazard)
                .onChange(of: viewModel.isHGVMode) { _, enabled in
                    if enabled { viewModel.applyHGVPreset() }
                }

            if viewModel.isHGVMode {
                Toggle("Avoid residential roads", isOn: $viewModel.avoidResidential)
                Toggle("Advisory hours clock (EU 561)", isOn: $viewModel.hosEnabled)
                    .tint(RFColor.hazard)
                    .onChange(of: viewModel.hosEnabled) { _, _ in
                        viewModel.persistHosEnabled()
                    }
            }

            HStack {
                TextField("Height (m)", text: $viewModel.vehicleHeight)
                    .textFieldStyle(GlassTextFieldStyle())
                TextField("Weight (t)", text: $viewModel.vehicleWeight)
                    .textFieldStyle(GlassTextFieldStyle())
            }
            HStack {
                TextField("Width (m)", text: $viewModel.vehicleWidth)
                    .textFieldStyle(GlassTextFieldStyle())
                TextField("Length (m)", text: $viewModel.vehicleLength)
                    .textFieldStyle(GlassTextFieldStyle())
            }

            NavigationLink {
                VehicleProfileManager(viewModel: viewModel)
            } label: {
                Label("Advanced vehicle profile", systemImage: "truck.box")
            }
        }
    }

    private var inspectionSection: some View {
        VStack(alignment: .leading, spacing: RFSpacing.sm) {
            Text("Walkaround inspection")
                .font(RFFont.sectionTitle)
            Text("DVSA-style local checklist. Official defect books remain authoritative.")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Button {
                viewModel.startWalkaroundInspection()
                showInspectionSheet = true
            } label: {
                Label("Walkaround check", systemImage: "checklist")
            }
            .buttonStyle(.borderless)
        }
        .padding(RFSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassPanel(cornerRadius: 14)
    }

    private var avoidanceSection: some View {
        VStack(alignment: .leading, spacing: RFSpacing.sm) {
            Text("Avoidance & Hazards")
                .font(RFFont.sectionTitle)

            Picker("Mode", selection: $viewModel.optimizationMode) {
                ForEach(OptimizationMode.allCases, id: \.self) { mode in
                    Text(mode.rawValue.capitalized).tag(mode)
                }
            }
            .pickerStyle(.menu)

            Toggle("Avoid Tolls", isOn: $viewModel.avoidTolls)
            Toggle("Avoid Ferries", isOn: $viewModel.avoidFerries)
            Toggle("Avoid Tunnels", isOn: $viewModel.avoidTunnels)
            Toggle("Hurry Mode", isOn: $viewModel.hurryMode)
                .tint(RFColor.hazard)
            Toggle("Avoid speed cameras", isOn: $viewModel.avoidCameras)
                .onChange(of: viewModel.avoidCameras) { _, _ in
                    Task { await viewModel.recalculateIfReady() }
                }
            Toggle("Avoid hazmat-restricted roads", isOn: $viewModel.avoidHazmatRestricted)
            if viewModel.isHGVMode {
                Picker("Hazmat class", selection: $viewModel.hazmatClass) {
                    Text("None").tag(HazmatClass?.none)
                    ForEach(HazmatClass.allCases.filter { $0 != .none }, id: \.self) { hazmat in
                        Text(hazmat.rawValue).tag(Optional(hazmat))
                    }
                }
                .pickerStyle(.menu)

                Picker("ADR tunnel code", selection: $viewModel.tunnelRestrictionCode) {
                    Text("None").tag(TunnelRestrictionCode?.none)
                    ForEach(TunnelRestrictionCode.allCases.filter { $0 != .none }, id: \.self) { code in
                        Text(code.rawValue.uppercased()).tag(Optional(code))
                    }
                }
                .pickerStyle(.menu)
            }
            Toggle("Enforce turn radius", isOn: $viewModel.enforceTurnRadius)
            Toggle("Curve speed advisories", isOn: $viewModel.enforceCurveSpeed)
            Toggle("Apple search fallback", isOn: $viewModel.useAppleSearchFallback)
                .help("Off by default — uses HeiGIT OpenRouteService geocoding only")
        }
    }

    private var navigationSection: some View {
        VStack(alignment: .leading, spacing: RFSpacing.sm) {
            Text("Navigation")
                .font(RFFont.sectionTitle)

            Picker("Position Source", selection: $viewModel.preferredTelemetryMode) {
                Text("Simulation").tag(LocationProviderMode.simulation)
                #if os(iOS)
                Text("Live GPS").tag(LocationProviderMode.hardwareGPS)
                #endif
            }
            .pickerStyle(.segmented)
            .onChange(of: viewModel.preferredTelemetryMode) { _, _ in
                viewModel.persistTelemetrySourceMode()
            }

            Toggle("Auto-optimize stops on route find", isOn: $viewModel.autoOptimizeOnRouteFind)
                .onChange(of: viewModel.autoOptimizeOnRouteFind) { _, _ in
                    viewModel.persistAutoOptimizeOnRouteFind()
                }

            #if os(iOS)
            Toggle("Voice guidance", isOn: $viewModel.voiceGuidanceEnabled)
                .onChange(of: viewModel.voiceGuidanceEnabled) { _, _ in
                    viewModel.persistVoiceGuidanceEnabled()
                }
            #endif
        }
    }

    private var offlineRoutingSection: some View {
        VStack(alignment: .leading, spacing: RFSpacing.sm) {
            Text("Offline Routing")
                .font(RFFont.sectionTitle)

            Toggle("Use offline routing when available", isOn: $viewModel.offlineRoutingEnabled)
                .onChange(of: viewModel.offlineRoutingEnabled) { _, _ in
                    viewModel.persistOfflineRoutingEnabled()
                }

            Toggle("Prefer offline routing", isOn: $viewModel.preferOfflineRouting)
                .onChange(of: viewModel.preferOfflineRouting) { _, _ in
                    viewModel.persistPreferOfflineRouting()
                }
                .help("When on, skip ORS and route on local/CDN graph tiles first.")

            TextField("Tile server URL (HTTPS)", text: $viewModel.tileServerURL)
                .textFieldStyle(GlassTextFieldStyle())
                .onSubmit { viewModel.persistTileServerURL() }

            Text("Pre-place `*.graphjson` under Application Support/RouteFinder/tiles/, or point at a CDN base. Full UK bbox is large — MVP uses a Norfolk demo corridor.")
                .font(.caption2)
                .foregroundStyle(.secondary)

            HStack {
                Button("Download demo corridor") {
                    Task { await viewModel.downloadDemoOfflineCorridor() }
                }
                .disabled(viewModel.isDownloadingOfflineTiles)

                Button("Ensure UK tiles") {
                    Task { await viewModel.downloadUKOfflineCorridor() }
                }
                .disabled(viewModel.isDownloadingOfflineTiles)
            }
            .buttonStyle(.borderless)

            if let status = viewModel.offlineTileStatus {
                Text(status)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var offlineMapSection: some View {
        VStack(alignment: .leading, spacing: RFSpacing.sm) {
            Text("Offline Map Pack")
                .font(RFFont.sectionTitle)

            Toggle("Use local map style when pack present", isOn: $viewModel.useLocalMapStyleWhenPackPresent)
                .onChange(of: viewModel.useLocalMapStyleWhenPackPresent) { _, _ in
                    viewModel.persistUseLocalMapStyleWhenPackPresent()
                }

            Text(viewModel.offlineMapPackStatus)
                .font(.caption2)
                .foregroundStyle(.secondary)

            Text("Expected layout: Application Support/RouteFinder/map-pack/style.json (+ tiles/). See MapLibreUI Resources/VENDOR_MAPLIBRE.md.")
                .font(.caption2)
                .foregroundStyle(.secondary)

            Button("Refresh pack status") {
                Task { await viewModel.refreshOfflineMapPackStatus() }
            }
            .buttonStyle(.borderless)
        }
    }

    private var environmentSection: some View {
        VStack(alignment: .leading, spacing: RFSpacing.sm) {
            Text("Road Conditions")
                .font(RFFont.sectionTitle)

            #if os(iOS)
            iosEnvironmentSection
            #else
            macEnvironmentSection
            #endif
        }
    }

    #if os(iOS)
    private var iosEnvironmentSection: some View {
        VStack(alignment: .leading, spacing: RFSpacing.sm) {
            Toggle("Automatic road conditions", isOn: automaticRoadConditionsBinding)
                .tint(RFColor.route)

            Picker("Conditions", selection: roadConditionSelectionBinding) {
                ForEach(EnvironmentalContext.allCases, id: \.self) { context in
                    Text(context.displayName).tag(context)
                }
            }
            .pickerStyle(.segmented)
            .disabled(weatherViewModel.isAutomatic)

            if weatherViewModel.isUpdating {
                Label("Updating from WeatherKit…", systemImage: "cloud.sun")
                    .font(RFFont.caption)
                    .foregroundStyle(.secondary)
            } else if weatherViewModel.isAutomatic {
                Text("Based on your location and WeatherKit.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } else {
                Text("Manual override active.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            if let lastError = weatherViewModel.lastError {
                Text(lastError)
                    .font(.caption2)
                    .foregroundStyle(.red)
                    .lineLimit(2)
            }
        }
    }

    private var automaticRoadConditionsBinding: Binding<Bool> {
        Binding(
            get: { weatherViewModel.isAutomatic },
            set: { isAutomatic in
                if isAutomatic {
                    weatherViewModel.useAutomatic()
                } else if weatherViewModel.manualOverride == nil {
                    weatherViewModel.userSelect(weatherViewModel.effectiveCondition)
                }
            }
        )
    }

    private var roadConditionSelectionBinding: Binding<EnvironmentalContext> {
        Binding(
            get: { weatherViewModel.effectiveCondition },
            set: { weatherViewModel.userSelect($0) }
        )
    }
    #endif

    #if os(macOS)
    private var macEnvironmentSection: some View {
        VStack(alignment: .leading, spacing: RFSpacing.sm) {
            Picker("Conditions", selection: $viewModel.environmentalContext) {
                ForEach(EnvironmentalContext.allCases, id: \.self) { context in
                    Text(context.displayName).tag(context)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: viewModel.environmentalContext) { _, _ in
                viewModel.refreshSimulationEnvironment()
            }
        }
    }
    #endif

    private var orsAPIKeySection: some View {
        VStack(alignment: .leading, spacing: RFSpacing.sm) {
            Text("HeiGIT API Key")
                .font(RFFont.sectionTitle)

            if viewModel.hasORSAPIKey {
                Text("Saved in Keychain as •••••••• — enter a new key to replace.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            SecureField("OpenRouteService API key", text: $viewModel.orsAPIKeyDraft)
                .textFieldStyle(GlassTextFieldStyle())
                .onSubmit { viewModel.persistORSAPIKey() }

            Text("Required for geocoding (`api.heigit.org/pelias/v1`) and HGV routing (`api.heigit.org/openrouteservice/v2`). Obtain a key from HeiGIT. Stored only in this Mac’s Keychain for your local account.")
                .font(.caption2)
                .foregroundStyle(.secondary)

            Button("Save API Key") {
                viewModel.persistORSAPIKey()
            }
            .buttonStyle(.borderless)
        }
    }

    private var openWeatherAPIKeySection: some View {
        VStack(alignment: .leading, spacing: RFSpacing.sm) {
            Text("OpenWeather API Key")
                .font(RFFont.sectionTitle)

            if viewModel.hasOpenWeatherAPIKey {
                Text("Saved in Keychain as •••••••• — enter a new key to replace.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            SecureField("OpenWeather API key", text: $viewModel.openWeatherAPIKeyDraft)
                .textFieldStyle(GlassTextFieldStyle())
                .onSubmit { viewModel.persistOpenWeatherAPIKey() }

            Text("Optional. Used for live weather-aware road conditions. Takes effect immediately after save (no restart). Get a key at openweathermap.org.")
                .font(.caption2)
                .foregroundStyle(.secondary)

            Button("Save OpenWeather Key") {
                viewModel.persistOpenWeatherAPIKey()
            }
            .buttonStyle(.borderless)
        }
    }

    private var dvlaAPIKeySection: some View {
        VStack(alignment: .leading, spacing: RFSpacing.sm) {
            Text("DVLA API Key (Fallback)")
                .font(RFFont.sectionTitle)

            if viewModel.hasDVLAAPIKey {
                Text("Saved in Keychain as •••••••• — enter a new key to replace.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            SecureField("Vehicle Enquiry Service API key", text: $viewModel.dvlaAPIKeyDraft)
                .textFieldStyle(GlassTextFieldStyle())
                .onSubmit { viewModel.persistDVLAAPIKey() }

            Text("Optional fallback. Enables UK registration lookup via driver-vehicle-licensing.api.gov.uk when RegCheck is unavailable.")
                .font(.caption2)
                .foregroundStyle(.secondary)

            Button("Save DVLA Key") {
                viewModel.persistDVLAAPIKey()
            }
            .buttonStyle(.borderless)
        }
    }

    private var regCheckUsernameSection: some View {
        VStack(alignment: .leading, spacing: RFSpacing.sm) {
            Text("RegCheck Username")
                .font(RFFont.sectionTitle)

            if viewModel.hasRegCheckUsername {
                Text("Saved in Keychain as •••••••• — enter a new username to replace.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            TextField("RegCheck account username", text: $viewModel.regCheckUsernameDraft)
                .textFieldStyle(GlassTextFieldStyle())
                .onSubmit { viewModel.persistRegCheckUsername() }

            Text("Primary UK registration lookup via regcheck.org.uk. Sign up at regcheck.org.uk to obtain a username.")
                .font(.caption2)
                .foregroundStyle(.secondary)

            Button("Save RegCheck Username") {
                viewModel.persistRegCheckUsername()
            }
            .buttonStyle(.borderless)
        }
    }

    private var tomTomAPIKeySection: some View {
        VStack(alignment: .leading, spacing: RFSpacing.sm) {
            Text("TomTom API Key")
                .font(RFFont.sectionTitle)

            if viewModel.hasTomTomAPIKey {
                Text("Saved in Keychain as •••••••• — enter a new key to replace.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            SecureField("TomTom Traffic Flow API key", text: $viewModel.tomTomAPIKeyDraft)
                .textFieldStyle(GlassTextFieldStyle())
                .onSubmit { viewModel.persistTomTomAPIKey() }

            Text("Optional. Enables live congestion scaling via TomTom Traffic Flow during route simulation.")
                .font(.caption2)
                .foregroundStyle(.secondary)

            Button("Save TomTom Key") {
                viewModel.persistTomTomAPIKey()
            }
            .buttonStyle(.borderless)
        }
    }

    private var fleetSection: some View {
        VStack(alignment: .leading, spacing: RFSpacing.sm) {
            Text("Fleet dispatch")
                .font(RFFont.sectionTitle)

            Toggle("Use remote fleet server", isOn: $viewModel.useRemoteFleetServer)
                .onChange(of: viewModel.useRemoteFleetServer) { _, _ in
                    viewModel.saveFleetServerURLFromSettings()
                }

            TextField("Fleet server URL", text: $viewModel.fleetServerURLText)
                .textFieldStyle(GlassTextFieldStyle())
                #if os(iOS)
                .textInputAutocapitalization(.never)
                .keyboardType(.URL)
                #endif
                .onSubmit { viewModel.saveFleetServerURLFromSettings() }

            Button("Discover fleet servers on LAN") {
                Task { await viewModel.discoverFleetServersOnLAN() }
            }
            .buttonStyle(.borderless)
            .disabled(viewModel.isDiscoveringFleetServers)

            if viewModel.isDiscoveringFleetServers {
                HStack(spacing: RFSpacing.xs) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Discovering fleet servers…")
                        .font(RFFont.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if let discoveryStatus = viewModel.fleetDiscoveryStatus {
                Text(discoveryStatus)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            ForEach(viewModel.discoveredFleetServers) { server in
                Button {
                    viewModel.applyDiscoveredFleetServer(server)
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(server.displayName)
                            .font(RFFont.caption)
                        Text(server.baseURL.absoluteString)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.borderless)
            }

            Text("Discovery requires the same Wi‑Fi or LAN. The dispatch Mac must run RouteFinderFleetServer with Bonjour enabled (default).")
                .font(.caption2)
                .foregroundStyle(.secondary)

            SecureField("Fleet API key (optional)", text: $viewModel.fleetServerAPIKeyText)
                .textFieldStyle(GlassTextFieldStyle())
                #if os(iOS)
                .textInputAutocapitalization(.never)
                #endif
                .onSubmit { viewModel.saveFleetServerURLFromSettings() }

            Text("LAN only — shared-secret auth when the server is started with --api-key. Use https:// when TLS is enabled. Changes apply immediately without restarting the app. Do not expose to the public internet.")
                .font(.caption2)
                .foregroundStyle(.secondary)

            Button("Save fleet server URL") {
                viewModel.saveFleetServerURLFromSettings()
            }
            .buttonStyle(.borderless)

            Button("Save fleet API key") {
                viewModel.saveFleetServerURLFromSettings()
            }
            .buttonStyle(.borderless)

            Button("Test fleet connection") {
                Task { await viewModel.testFleetServerConnection() }
            }
            .buttonStyle(.borderless)

            if let status = viewModel.fleetServerConnectionStatus {
                Text(status)
                    .font(.caption2)
                    .foregroundStyle(status.contains("Connected") ? .green : .secondary)
            }

            TextField("Fleet vehicle UUID", text: $viewModel.fleetVehicleIdText)
                .textFieldStyle(GlassTextFieldStyle())
                .onSubmit { viewModel.saveFleetVehicleIdFromSettings() }

            Text("Vehicle id must match the dispatch console picker. Enable remote server for multi-device sync over LAN.")
                .font(.caption2)
                .foregroundStyle(.secondary)

            Button("Save vehicle id") {
                viewModel.saveFleetVehicleIdFromSettings()
            }
            .buttonStyle(.borderless)

            Button("Check for dispatch") {
                Task { await viewModel.pollAndApplyFleetDispatch() }
            }
            .buttonStyle(.borderless)

            Button("Accept demo dispatch") {
                Task {
                    do {
                        try await viewModel.acceptDemoFleetDispatch()
                    } catch {
                        viewModel.errorMessage = "Demo dispatch failed: \(error.localizedDescription)"
                    }
                }
            }
            .buttonStyle(.borderless)

            #if os(iOS)
            if horizontalSizeClass == .compact {
                Button("Open dispatch console") {
                    showDispatchConsole = true
                }
                .buttonStyle(.borderless)
            }
            #endif
        }
    }
}
