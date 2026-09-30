import Contracts
import DataLayer
import RouteController
import SwiftUI
import UniformTypeIdentifiers
#if os(iOS)
import AVFoundation
#endif
#if os(macOS)
import AppKit
#endif

/// Settings sheet for algorithm, vehicle, avoidance, and HeiGIT API configuration.
struct SettingsSheet: View {
    @Bindable var viewModel: RouteViewModel
    var onDismiss: (() -> Void)? = nil
    @Environment(\.dismiss) private var dismiss
    #if os(macOS)
    @Environment(\.openWindow) private var openWindow
    #endif
    #if os(iOS)
    @EnvironmentObject private var weatherViewModel: WeatherViewModel
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    #endif
    #if os(iOS)
    @State private var showInspectionSheet = false
    #endif
    @State private var showDispatchConsole = false
    @State private var showProductOnboarding = false
    @State private var showFleetSetupWizard = false
    @State private var showLaunchRoleSheet = false
    @State private var showTelematicsImporter = false
    @State private var settingsPath = NavigationPath()
    #if os(macOS)
    @State private var requireLoginEachLaunch = SessionWorkspaceSettings.loadRequireLoginEachLaunch()
    #endif

    private enum SettingsHubRoute: Hashable {
        case apiKeys
    }

    var body: some View {
        NavigationStack(path: $settingsPath) {
            settingsHub
            .navigationTitle("Settings")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        onDismiss?()
                        dismiss()
                    }
                }
            }
            .navigationDestination(for: SettingsHubRoute.self) { route in
                switch route {
                case .apiKeys:
                    settingsDetailPage(title: "API Keys") {
                        apiUsageSection
                        orsAPIKeySection
                        openWeatherAPIKeySection
                        regCheckUsernameSection
                        dvlaAPIKeySection
                        tomTomAPIKeySection
                    }
                }
            }
            .onAppear {
                if NavigationWorkspaceSettings.consumeSettingsDeepLink() == .apiKeys {
                    settingsPath.append(SettingsHubRoute.apiKeys)
                }
            }
            #if os(iOS)
            .sheet(isPresented: $showInspectionSheet) {
                InspectionWalkaroundSheet(viewModel: viewModel)
            }
            #endif
            .sheet(isPresented: $showDispatchConsole) {
                DispatchConsoleView()
            }
            .sheet(isPresented: $showProductOnboarding) {
                ProductOnboardingSheet()
            }
            .sheet(isPresented: $showFleetSetupWizard) {
                FleetSetupWizardView(viewModel: viewModel)
            }
            .sheet(isPresented: $showLaunchRoleSheet) {
                LaunchRoleSheet { role in
                    NavigationWorkspaceSettings.saveLaunchRole(role)
                    NavigationWorkspaceSettings.saveHasCompletedRoleSelection(true)
                    NavigationWorkspaceSettings.saveHasCompletedRoleFollowUp(false)
                    showLaunchRoleSheet = false
                }
            }
        }
        #if os(macOS)
        .frame(width: macSheetSize.width, height: macSheetSize.height)
        .onAppear {
            MacAppActivation.activateForTextInput()
        }
        #endif
    }

    private var settingsHub: some View {
        List {
            NavigationLink {
                settingsDetailPage(title: "Vehicle & HGV") {
                    algorithmSection
                    vehicleSection
                    if viewModel.isHGVMode {
                        TachoAdvisorySettingsSection(viewModel: viewModel)
                        #if os(iOS)
                        inspectionSection
                        #else
                        walkaroundMacHintSection
                        #endif
                    }
                    avoidanceSection
                }
            } label: {
                Label("Vehicle & HGV", systemImage: "truck.box.fill")
            }
            .accessibilityIdentifier("settingsVehicleHGV")

            NavigationLink {
                settingsDetailPage(title: "Navigation & Voice") {
                    navigationSection
                    environmentSection
                }
            } label: {
                Label("Navigation & Voice", systemImage: "location.north.line.fill")
            }
            .accessibilityIdentifier("settingsNavigation")

            NavigationLink {
                settingsDetailPage(title: "Search & Maps") {
                    searchLanguageSection
                    offlineMapSection
                }
            } label: {
                Label("Search & Maps", systemImage: "map.fill")
            }

            NavigationLink(value: SettingsHubRoute.apiKeys) {
                Label("API Keys", systemImage: "key.fill")
            }
            .accessibilityIdentifier("settingsAPIKeys")

            NavigationLink {
                settingsDetailPage(title: "Fleet & Dispatch") {
                    fleetSection
                }
            } label: {
                Label("Fleet & Dispatch", systemImage: "antenna.radiowaves.left.and.right")
            }
            .accessibilityIdentifier("settingsFleetDispatch")

            NavigationLink {
                settingsDetailPage(title: "Offline Routing") {
                    offlineRoutingSection
                }
            } label: {
                Label("Offline Routing", systemImage: "arrow.triangle.branch")
            }

            NavigationLink {
                settingsDetailPage(title: "Legal") {
                    legalSection
                }
            } label: {
                Label("Legal", systemImage: "doc.text")
            }
            .accessibilityIdentifier("settingsLegal")

            Section {
                helpSection
                OSMAttributionFooter()
            }
        }
    }

    private func settingsDetailPage<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: RFSpacing.lg) {
                content()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(RFSpacing.lg)
            .padding(.bottom, RFSpacing.xl)
        }
        .navigationTitle(title)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
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
                    viewModel.scheduleVehicleWorkspacePersist()
                }

            if viewModel.isHGVMode {
                Toggle("Avoid residential roads", isOn: $viewModel.avoidResidential)
                    .onChange(of: viewModel.avoidResidential) { _, _ in
                        viewModel.scheduleVehicleWorkspacePersist()
                    }
                Toggle("Advisory hours clock (EU 561)", isOn: $viewModel.hosEnabled)
                    .tint(RFColor.hazard)
                    .onChange(of: viewModel.hosEnabled) { _, _ in
                        viewModel.persistHosEnabled()
                    }
            }

            HStack {
                TextField("Height (m)", text: $viewModel.vehicleHeight)
                    .textFieldStyle(GlassTextFieldStyle())
                    .onChange(of: viewModel.vehicleHeight) { _, _ in
                        viewModel.scheduleVehicleWorkspacePersist()
                    }
                TextField("Weight (t)", text: $viewModel.vehicleWeight)
                    .textFieldStyle(GlassTextFieldStyle())
                    .onChange(of: viewModel.vehicleWeight) { _, _ in
                        viewModel.scheduleVehicleWorkspacePersist()
                    }
            }
            HStack {
                TextField("Width (m)", text: $viewModel.vehicleWidth)
                    .textFieldStyle(GlassTextFieldStyle())
                    .onChange(of: viewModel.vehicleWidth) { _, _ in
                        viewModel.scheduleVehicleWorkspacePersist()
                    }
                TextField("Length (m)", text: $viewModel.vehicleLength)
                    .textFieldStyle(GlassTextFieldStyle())
                    .onChange(of: viewModel.vehicleLength) { _, _ in
                        viewModel.scheduleVehicleWorkspacePersist()
                    }
            }

            NavigationLink {
                VehicleProfileManager(viewModel: viewModel)
            } label: {
                Label("Advanced vehicle profile", systemImage: "truck.box")
            }
        }
    }

    #if os(iOS)
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
    #else
    /// Mac is desk-only for walkaround: checklist runs on the cab phone; defects land in Dispatch.
    private var walkaroundMacHintSection: some View {
        VStack(alignment: .leading, spacing: RFSpacing.sm) {
            Text("Walkaround inspection")
                .font(RFFont.sectionTitle)
            Text("Complete the DVSA-style walkaround on the cab iPhone (or iPad driver). Defects appear on Mac Dispatch after the driver saves — this Mac is not the inspection surface.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(RFSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassPanel(cornerRadius: 14)
    }
    #endif

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
            Toggle("Avoid non-compliant LEZ / CAZ", isOn: $viewModel.avoidNonCompliantLEZ)
                .onChange(of: viewModel.avoidNonCompliantLEZ) { _, _ in
                    viewModel.scheduleVehicleWorkspacePersist()
                }
                .help("Routes around UK ULEZ/CAZ zones when emission class is missing or below Euro 6. Destinations inside a zone are still allowed.")
            Text("LEZ rings are simplified envelopes — not legal cadastral boundaries. Euro 6 exempt vehicles skip avoid routing when class is set in the vehicle profile.")
                .font(.caption2)
                .foregroundStyle(.secondary)
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

    private var searchLanguageSection: some View {
        VStack(alignment: .leading, spacing: RFSpacing.sm) {
            Text("Language")
                .font(RFFont.sectionTitle)

            Picker("Search display language", selection: $viewModel.preferredSearchLanguage) {
                ForEach(LanguageWorkspaceSettings.supportedOptions) { option in
                    Text(option.label).tag(option.code)
                }
            }
            .pickerStyle(.menu)
            .onChange(of: viewModel.preferredSearchLanguage) { _, _ in
                viewModel.persistLanguageWorkspaceSettings()
            }

            Picker("Map label language", selection: $viewModel.preferredMapLabelLanguage) {
                ForEach(LanguageWorkspaceSettings.supportedOptions) { option in
                    Text(option.label).tag(option.code)
                }
            }
            .pickerStyle(.menu)
            .onChange(of: viewModel.preferredMapLabelLanguage) { _, _ in
                viewModel.persistLanguageWorkspaceSettings()
            }

            Toggle("English name fallback", isOn: $viewModel.searchEnglishFallback)
                .onChange(of: viewModel.searchEnglishFallback) { _, _ in
                    viewModel.persistLanguageWorkspaceSettings()
                }
                .help("When few localized results are found, also search in English (e.g. Warsaw instead of Warszawa). Special characters you type are preserved in results.")

            Text("Search results and pin labels use Pelias. Basemap road and place names follow the map label language where OpenStreetMap provides translations.")
                .font(.caption2)
                .foregroundStyle(.secondary)
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

            speechVoiceSettings
            #endif

            Toggle("Apply live traffic to cruise speed", isOn: $viewModel.applyTrafficToSimulation)
                .onChange(of: viewModel.applyTrafficToSimulation) { _, _ in
                    viewModel.persistApplyTrafficToSimulation()
                }
                .help("When off, TomTom traffic still informs reroutes but does not cap steady-state simulation speed.")

            Toggle("Avoid traffic delays when routing", isOn: $viewModel.avoidTrafficDelaysWhenRouting)
                .onChange(of: viewModel.avoidTrafficDelaysWhenRouting) { _, _ in
                    viewModel.persistAvoidTrafficDelaysWhenRouting()
                }
                .help("When on, live TomTom standstills can trigger an ORS avoid-polygon recalculation after route find.")

            if viewModel.isHGVMode {
                Toggle("Break Now quick action", isOn: $viewModel.breakNowQuickActionEnabled)
                    .onChange(of: viewModel.breakNowQuickActionEnabled) { _, _ in
                        viewModel.persistBreakNowQuickActionEnabled()
                    }
                    .help("Shows a one-tap Break Now control to find the nearest layby ahead on the active route.")

                Toggle("Layby voice alerts", isOn: $viewModel.laybyVoiceAlertsEnabled)
                    .onChange(of: viewModel.laybyVoiceAlertsEnabled) { _, _ in
                        viewModel.persistLaybyVoiceAlertsEnabled()
                    }
                    .help("Speaks once when an upcoming layby enters the advisory window during navigation or simulation.")

                Toggle("Closure & traffic alerts", isOn: $viewModel.hazardVoiceAlertsEnabled)
                    .onChange(of: viewModel.hazardVoiceAlertsEnabled) { _, _ in
                        viewModel.persistHazardVoiceAlertsEnabled()
                    }
                    .help("Speaks once when a reported closure or traffic hazard enters the advisory window during navigation.")

                Toggle("Clearance radar (bridges)", isOn: $viewModel.clearanceRadarEnabled)
                    .onChange(of: viewModel.clearanceRadarEnabled) { _, _ in
                        viewModel.persistClearanceRadarEnabled()
                    }
                    .help("Queries OSM maxheight/maxweight along the route corridor and warns when the active HGV profile may not fit.")

                Picker("Fuel card provider", selection: $viewModel.fuelCardProvider) {
                    ForEach(FuelCardProvider.allCases) { provider in
                        Text(provider.displayName).tag(provider)
                    }
                }
                .onChange(of: viewModel.fuelCardProvider) { _, _ in
                    viewModel.persistFuelCardProvider()
                }
                .accessibilityIdentifier("settingsFuelCardProvider")
                .help("Highlights truck fuel stops ahead that likely accept your fleet card (name/brand match on OpenStreetMap data).")
            }

            #if os(macOS)
            Toggle("Require login each launch", isOn: $requireLoginEachLaunch)
                .onChange(of: requireLoginEachLaunch) { _, value in
                    SessionWorkspaceSettings.saveRequireLoginEachLaunch(value)
                }
            #endif
        }
    }

    #if os(iOS)
    private var speechVoiceSettings: some View {
        Group {
            let voices = AVSpeechSynthesisVoice.speechVoices()
                .filter { $0.language.hasPrefix("en") }
                .sorted { $0.name < $1.name }

            Picker("Voice", selection: Binding(
                get: { viewModel.speechVoiceIdentifier ?? "" },
                set: { viewModel.speechVoiceIdentifier = $0.isEmpty ? nil : $0 }
            )) {
                Text("System default (enhanced)").tag("")
                ForEach(voices, id: \.identifier) { voice in
                    Text(voice.name).tag(voice.identifier)
                }
            }
            .onChange(of: viewModel.speechVoiceIdentifier) { _, _ in
                viewModel.persistSpeechVoiceSettings()
            }

            VStack(alignment: .leading, spacing: RFSpacing.xs) {
                Text("Speech rate")
                    .font(RFFont.caption)
                    .foregroundStyle(.secondary)
                Slider(value: $viewModel.speechRate, in: 0.35...0.65, step: 0.02)
                    .onChange(of: viewModel.speechRate) { _, _ in
                        viewModel.persistSpeechVoiceSettings()
                    }
            }
        }
    }
    #endif

    private var helpSection: some View {
        VStack(alignment: .leading, spacing: RFSpacing.sm) {
            Text("Help")
                .font(RFFont.sectionTitle)

            Button {
                showLaunchRoleSheet = true
            } label: {
                Label("Getting started", systemImage: "person.3.fill")
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("settingsGettingStarted")

            if let role = NavigationWorkspaceSettings.loadLaunchRole() {
                Text("Current role: \(role.title)")
                    .font(RFFont.caption)
                    .foregroundStyle(.secondary)
            }

            Button {
                showProductOnboarding = true
            } label: {
                Label("How RouteFinder works", systemImage: "questionmark.circle")
            }
            .buttonStyle(.plain)
        }
    }

    private var legalSection: some View {
        VStack(alignment: .leading, spacing: RFSpacing.sm) {
            Text("Legal")
                .font(RFFont.sectionTitle)

            DisclosureGroup("Driver Terms") {
                Text(ProductOnboardingSheet.driverTermsBody)
                    .font(RFFont.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, RFSpacing.xs)

                if NavigationWorkspaceSettings.loadHasAcceptedRoutingLiability() {
                    Text("Accepted on this device.")
                        .font(RFFont.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Not yet accepted — Terms appear again on next cold launch.")
                        .font(RFFont.caption)
                        .foregroundStyle(.orange)
                }
            }

            DisclosureGroup("Privacy Policy") {
                Text(ProductLegalDocuments.privacyPolicySummary)
                    .font(RFFont.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, RFSpacing.xs)
                if let url = ProductLegalDocuments.privacyPolicyURL {
                    Link("Open full Privacy Policy", destination: url)
                        .font(RFFont.caption)
                        .accessibilityIdentifier("legalPrivacyPolicyLink")
                }
            }

            DisclosureGroup("Terms of Service") {
                Text(ProductLegalDocuments.termsOfServiceSummary)
                    .font(RFFont.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, RFSpacing.xs)
                if let url = ProductLegalDocuments.termsOfServiceURL {
                    Link("Open full Terms of Service", destination: url)
                        .font(RFFont.caption)
                        .accessibilityIdentifier("legalTermsOfServiceLink")
                }
            }
        }
        .padding(RFSpacing.md)
        .glassPanel(cornerRadius: 14)
    }

    private var offlineRoutingSection: some View {
        VStack(alignment: .leading, spacing: RFSpacing.sm) {
            Text("Offline Routing")
                .font(RFFont.sectionTitle)

            Toggle("Use offline routing when available", isOn: $viewModel.offlineRoutingEnabled)
                .onChange(of: viewModel.offlineRoutingEnabled) { _, _ in
                    viewModel.persistOfflineRoutingEnabled()
                }
                .help("Only used when local *.graphjson tiles exist or a tile server URL is set. Otherwise ORS is used when keyed.")

            Toggle("Prefer offline routing", isOn: $viewModel.preferOfflineRouting)
                .onChange(of: viewModel.preferOfflineRouting) { _, _ in
                    viewModel.persistPreferOfflineRouting()
                }
                .help("When on, skip ORS and route on local/CDN graph tiles first.")

            if viewModel.offlineRoutingEnabled {
                Text("No offline tiles installed yet — a cloud ORS key is required until you Download demo corridor or place `*.graphjson` under Application Support/RouteFinder/tiles/.")
                    .font(.caption2)
                    .foregroundStyle(.orange)
            }

            TextField("Tile server URL (HTTPS)", text: $viewModel.tileServerURL)
                .textFieldStyle(GlassTextFieldStyle())
                .onSubmit { viewModel.persistTileServerURL() }

            Text("Pre-place `*.graphjson` under Application Support/RouteFinder/tiles/, or point at a CDN base. Full UK bbox is large — MVP uses a Norfolk demo corridor.")
                .font(.caption2)
                .foregroundStyle(.secondary)

            Picker("Download region", selection: $viewModel.selectedOfflineDownloadRegion) {
                ForEach(OfflineDownloadRegion.allCases) { region in
                    Text(region.displayName).tag(region)
                }
            }
            .pickerStyle(.menu)

            Text(viewModel.selectedOfflineDownloadRegion.sizeWarning)
                .font(.caption2)
                .foregroundStyle(.secondary)

            Button("Download selected region") {
                Task { await viewModel.downloadSelectedOfflineRegion() }
            }
            .buttonStyle(.borderless)
            .disabled(viewModel.isDownloadingOfflineTiles)

            if viewModel.isDownloadingOfflineTiles {
                ProgressView(value: viewModel.offlineDownloadProgress)
                    .progressViewStyle(.linear)
            }

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

            Text("Pack path: \(viewModel.offlineMapPackDirectoryPath)")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .textSelection(.enabled)

            Text("Expected layout: Application Support/RouteFinder/map-pack/style.json (+ tiles/). See MapLibreUI Resources/VENDOR_MAPLIBRE.md.")
                .font(.caption2)
                .foregroundStyle(.secondary)

            HStack {
                Button("Refresh pack status") {
                    Task { await viewModel.refreshOfflineMapPackStatus() }
                }
                .buttonStyle(.borderless)
                #if os(macOS)
                Button("Reveal in Finder") {
                    NSWorkspace.shared.activateFileViewerSelecting(
                        [URL(fileURLWithPath: viewModel.offlineMapPackDirectoryPath)]
                    )
                }
                .buttonStyle(.borderless)
                #endif
            }
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

    private var apiUsageSection: some View {
        VStack(alignment: .leading, spacing: RFSpacing.sm) {
            Text("API Usage Today")
                .font(RFFont.sectionTitle)

            if let banner = viewModel.apiUsageBudgetBanner {
                Text(banner)
                    .font(.caption)
                    .foregroundStyle(.orange)
            }

            if let summary = viewModel.apiUsageSummary {
                ForEach(APIUsageProvider.allCases, id: \.self) { provider in
                    let count = summary.count(for: provider)
                    let budget = APIUsageBudget.defaultBudget(for: provider).softDailyLimit
                    HStack {
                        Text(provider.displayName)
                        Spacer()
                        Text("\(count) / \(budget)")
                            .foregroundStyle(count >= budget ? .orange : .secondary)
                    }
                    .font(.caption)
                }
            } else {
                Text("Loading usage…")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Button("Refresh Usage") {
                Task { await viewModel.refreshAPIUsageSummary() }
            }
            .buttonStyle(.borderless)
        }
        .task {
            await viewModel.refreshAPIUsageSummary()
        }
    }

    private var orsAPIKeySection: some View {
        VStack(alignment: .leading, spacing: RFSpacing.sm) {
            Text("HeiGIT API Key")
                .font(RFFont.sectionTitle)

            if viewModel.usesFleetORSProxy {
                Text("Included with your fleet plan — address search and routing go through the office fleet server (operator-paid). You do not need a personal HeiGIT key on this device while remote fleet sync is on.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                DisclosureGroup("Advanced: local HeiGIT key (optional offline / solo use)") {
                    orsKeyFields
                }
            } else {
                orsKeyFields
            }
        }
    }

    private var orsKeyFields: some View {
        VStack(alignment: .leading, spacing: RFSpacing.sm) {
            if viewModel.hasORSAPIKey {
                Text("Saved in Keychain as •••••••• — enter a new key to replace.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            SecureField("OpenRouteService API key", text: $viewModel.orsAPIKeyDraft)
                .textFieldStyle(GlassTextFieldStyle())
                .onSubmit { viewModel.persistORSAPIKey() }
                .onChange(of: viewModel.orsAPIKeyDraft) { _, _ in
                    if viewModel.settingsSaveConfirmation != nil {
                        viewModel.settingsSaveConfirmation = nil
                    }
                }

            #if os(iOS)
            Text("Required for address search and HGV routing when not using the fleet ORS proxy. Obtain a key from HeiGIT. Paste the key, then tap Save API Key.")
                .font(.caption2)
                .foregroundStyle(.secondary)
            #else
            Text("Required for address search and HGV routing when not using the fleet ORS proxy. Obtain a key from HeiGIT. Use the signed RouteFinderMac Xcode scheme.")
                .font(.caption2)
                .foregroundStyle(.secondary)
            #endif

            Button("Save API Key") {
                viewModel.persistORSAPIKey()
            }
            .buttonStyle(.borderless)
            .accessibilityIdentifier("settingsSaveORSAPIKey")

            if viewModel.settingsSaveConfirmation != nil {
                Text(viewModel.settingsSaveConfirmation ?? "")
                    .font(.caption2)
                    .foregroundStyle(.green)
                    .accessibilityIdentifier("settingsORSAPIKeySaved")
            }
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
        VStack(alignment: .leading, spacing: RFSpacing.lg) {
            fleetConnectionGroup
            fleetVehicleGroup
            fleetDeskActionsGroup
            fleetAdvancedGroup
        }
    }

    private var fleetConnectionGroup: some View {
        VStack(alignment: .leading, spacing: RFSpacing.sm) {
            Text("Connection")
                .font(RFFont.sectionTitle)

            if let status = viewModel.fleetServerConnectionStatus {
                Text(status)
                    .font(RFFont.caption.weight(.semibold))
                    .foregroundStyle(fleetConnectionStatusColor(status))
            }

            Toggle("Use remote fleet server", isOn: $viewModel.useRemoteFleetServer)
                .onChange(of: viewModel.useRemoteFleetServer) { _, _ in
                    viewModel.saveFleetServerURLFromSettings()
                }

            TextField("Fleet server URL (LAN or https://…)", text: $viewModel.fleetServerURLText)
                .textFieldStyle(GlassTextFieldStyle())
                #if os(iOS)
                .textInputAutocapitalization(.never)
                .keyboardType(.URL)
                #endif
                .onSubmit { viewModel.saveFleetServerURLFromSettings() }

            Text("LAN: http://192.168.x.x:8080 · Hosted: https://… with org bearer (never the operator ORS key).")
                .font(.caption2)
                .foregroundStyle(.secondary)

            SecureField("Fleet API key (same as `--api-key`)", text: $viewModel.fleetServerAPIKeyText)
                .textFieldStyle(GlassTextFieldStyle())
                #if os(iOS)
                .textInputAutocapitalization(.never)
                #endif
                .onSubmit { viewModel.saveFleetServerURLFromSettings() }

            HStack(spacing: RFSpacing.sm) {
                Button("Save URL") {
                    viewModel.saveFleetServerURLFromSettings()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button("Save API key") {
                    viewModel.saveFleetServerURLFromSettings()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button("Test connection") {
                    Task { await viewModel.testFleetServerConnection() }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }

            Button("Discover fleet servers on LAN") {
                Task { await viewModel.discoverFleetServersOnLAN() }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
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
        }
        .glassPanel(cornerRadius: 14)
        .padding(RFSpacing.sm)
    }

    private var fleetVehicleGroup: some View {
        VStack(alignment: .leading, spacing: RFSpacing.sm) {
            Text("Vehicle")
                .font(RFFont.sectionTitle)

            TextField("Fleet vehicle UUID", text: $viewModel.fleetVehicleIdText)
                .textFieldStyle(GlassTextFieldStyle())
                .onSubmit { viewModel.saveFleetVehicleIdFromSettings() }

            Text("Must match the Dispatch QR / picker. Prefer the fleet setup wizard to scan.")
                .font(.caption2)
                .foregroundStyle(.secondary)

            HStack(spacing: RFSpacing.sm) {
                Button("Save vehicle id") {
                    viewModel.saveFleetVehicleIdFromSettings()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button("Open fleet setup wizard") {
                    showFleetSetupWizard = true
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
        }
        .glassPanel(cornerRadius: 14)
        .padding(RFSpacing.sm)
    }

    private var fleetDeskActionsGroup: some View {
        VStack(alignment: .leading, spacing: RFSpacing.sm) {
            Text("Desk actions")
                .font(RFFont.sectionTitle)

            #if os(macOS)
            Text("Push trips from the browser console. This Mac app is for map simulation.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Button("Open web dispatch") {
                WebDispatchDesk.openLocalDevInBrowser()
                if let onDismiss {
                    onDismiss()
                } else {
                    dismiss()
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)
            .accessibilityIdentifier("settingsOpenWebDispatchMac")
            #endif
            #if os(iOS)
            if horizontalSizeClass == .compact {
                Button("Open dispatch console") {
                    showDispatchConsole = true
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
            }
            #endif

            Button("Check for dispatch") {
                Task { await viewModel.pollAndApplyFleetDispatch() }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .glassPanel(cornerRadius: 14)
        .padding(RFSpacing.sm)
    }

    private var fleetAdvancedGroup: some View {
        DisclosureGroup {
            VStack(alignment: .leading, spacing: RFSpacing.sm) {
                #if os(macOS)
                Text("Legacy native Dispatch window (prefer web-dispatch).")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Button("Open legacy Dispatch window") {
                    openWindow(id: "dispatch")
                    if let onDismiss {
                        onDismiss()
                    } else {
                        dismiss()
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .accessibilityIdentifier("settingsOpenDispatchMacLegacy")
                #endif

                Button("Load offline demo job (no LAN)") {
                    Task {
                        do {
                            try await viewModel.acceptDemoFleetDispatch()
                        } catch {
                            viewModel.errorMessage = error.localizedDescription
                        }
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(viewModel.useRemoteFleetServer && viewModel.fleetVehicleId != nil)

                if viewModel.useRemoteFleetServer && viewModel.fleetVehicleId != nil {
                    Text("Turn off remote fleet first — offline demo would replace your paired vehicle id.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Text("Telematics (read-only)")
                    .font(RFFont.caption.weight(.semibold))
                    .padding(.top, RFSpacing.xs)

                Text("Import a Geotab/Samsara-style CSV of last-known positions for dispatch display. Not legal VU.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Button("Import CSV…") {
                    showTelematicsImporter = true
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button("Reload last import") {
                    Task { await viewModel.reloadTelematicsImport() }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                if let batch = viewModel.telematicsImportBatch {
                    Text("Last import: \(batch.pings.count) vehicle(s) at \(batch.importedAt.formatted())")
                        .font(.caption2)
                    ForEach(batch.pings.prefix(5)) { ping in
                        Text("\(ping.vehicleLabel) · \(String(format: "%.4f", ping.latitude)), \(String(format: "%.4f", ping.longitude))")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Button("Clear import") {
                        Task { await viewModel.clearTelematicsImport() }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }

                if let error = viewModel.telematicsImportError {
                    Text(error)
                        .font(.caption2)
                        .foregroundStyle(.red)
                }
            }
            .padding(.top, RFSpacing.xs)
            .fileImporter(
                isPresented: $showTelematicsImporter,
                allowedContentTypes: [.commaSeparatedText, .plainText],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    guard let url = urls.first else { return }
                    Task { await viewModel.importTelematicsCSV(from: url) }
                case .failure(let error):
                    viewModel.telematicsImportError = error.localizedDescription
                }
            }
            .task {
                await viewModel.reloadTelematicsImport()
            }
        } label: {
            Text("Advanced / telematics")
                .font(RFFont.sectionTitle)
        }
        .glassPanel(cornerRadius: 14)
        .padding(RFSpacing.sm)
    }

    private func fleetConnectionStatusColor(_ status: String) -> Color {
        switch FleetServerHealthLabel.accent(forStatus: status) {
        case .success: return .green
        case .failure: return .red
        case .neutral: return .secondary
        }
    }
}
