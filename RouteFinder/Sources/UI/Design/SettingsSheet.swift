import Contracts
import RouteController
import SwiftUI

/// Settings sheet for algorithm, vehicle, avoidance, and HeiGIT API configuration.
struct SettingsSheet: View {
    @Bindable var viewModel: RouteViewModel
    @Environment(\.dismiss) private var dismiss
    #if os(iOS)
    @EnvironmentObject private var weatherViewModel: WeatherViewModel
    #endif

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: RFSpacing.lg) {
                    algorithmSection
                    vehicleSection
                    avoidanceSection
                    environmentSection
                    navigationSection
                    orsAPIKeySection
                    openWeatherAPIKeySection
                    regCheckUsernameSection
                    dvlaAPIKeySection
                    tomTomAPIKeySection
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

            Text("Optional. Used for live weather-aware routing when --weather is not set. Get a key at openweathermap.org.")
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
}
