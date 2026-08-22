import Contracts
import SwiftUI

/// Unified left sidebar containing all route controls.
struct ControlSheet: View {
    @Bindable var viewModel: RouteViewModel

    @State private var routeSearchExpanded = true
    @State private var algorithmExpanded = true
    @State private var vehicleExpanded = true
    @State private var avoidanceExpanded = true
    @State private var settingsExpanded = false
    @FocusState private var focusedWaypointID: UUID?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: RFSpacing.lg) {
                Text("RouteFinder")
                    .font(.title2.weight(.semibold))
                    .vibrancyLabel()

                CollapsibleSection(title: "Route Search", isExpanded: $routeSearchExpanded) {
                    RouteSearchFields(viewModel: viewModel, focusedWaypointID: $focusedWaypointID)

                    HStack(spacing: RFSpacing.sm) {
                        Button("Add Stop") {
                            viewModel.addWaypoint()
                        }
                        .buttonStyle(.borderless)

                        Spacer()

                        Button {
                            Task { await viewModel.findRoute() }
                        } label: {
                            if viewModel.isCalculating {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Text("Find Route")
                            }
                        }
                        .modifier(GlassButton())
                        .disabled(!viewModel.canFindRoute || viewModel.isCalculating)
                    }
                }
                .zIndex(10)

                CollapsibleSection(title: "Algorithm", isExpanded: $algorithmExpanded) {
                    AlgorithmSection(viewModel: viewModel)
                }

                CollapsibleSection(title: "Vehicle Profile", isExpanded: $vehicleExpanded) {
                    VehicleProfileSection(viewModel: viewModel)
                }

                CollapsibleSection(title: "Avoidance & Hazard Settings", isExpanded: $avoidanceExpanded) {
                    AvoidanceSection(viewModel: viewModel)
                }

                CollapsibleSection(title: "Settings", isExpanded: $settingsExpanded) {
                    SettingsSection(viewModel: viewModel)
                }

                OSMAttributionFooter()
            }
            .padding(RFSpacing.md + 4)
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .controlSheetStyle()
        .sheet(item: $viewModel.pendingDisambiguation) { request in
            GeocodeDisambiguationSheet(
                query: request.query,
                candidates: request.candidates,
                onSelect: { suggestion in
                    Task { await viewModel.resolveDisambiguation(suggestion) }
                },
                onCancel: { viewModel.cancelDisambiguation() }
            )
        }
        .sheet(item: $viewModel.routeFailure) { failure in
            RouteFailureSheet(presentation: failure) {
                viewModel.routeFailure = nil
            }
        }
    }
}

// MARK: - Algorithm Section

private struct AlgorithmSection: View {
    @Bindable var viewModel: RouteViewModel

    var body: some View {
        Picker("Algorithm", selection: $viewModel.useAStar) {
            Text("A*").tag(true)
            Text("Dijkstra").tag(false)
        }
        .pickerStyle(.segmented)
    }
}

// MARK: - Vehicle Profile Section

private struct VehicleProfileSection: View {
    @Bindable var viewModel: RouteViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: RFSpacing.sm) {
            Toggle("HGV / Truck Mode", isOn: $viewModel.isHGVMode)
                .tint(RFColor.hazard)
                .onChange(of: viewModel.isHGVMode) { _, enabled in
                    if enabled { viewModel.applyHGVPreset() }
                }

            if viewModel.isHGVMode {
                HGVModeBadge()
                Toggle("Avoid residential roads", isOn: $viewModel.avoidResidential)
                Text("UK artic preset: 4.0 m × 2.55 m × 16.5 m · 44 t")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
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
        }
        .animation(.spring(response: 0.35), value: viewModel.isHGVMode)
    }
}

// MARK: - Avoidance Section

private struct AvoidanceSection: View {
    @Bindable var viewModel: RouteViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: RFSpacing.sm) {
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
            if viewModel.hurryMode { HurryModeBadge() }
        }
        .animation(.spring(response: 0.35), value: viewModel.hurryMode)
    }
}

// MARK: - Settings Section

private struct SettingsSection: View {
    @Bindable var viewModel: RouteViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: RFSpacing.sm) {
            Toggle("Apple search fallback", isOn: $viewModel.useAppleSearchFallback)
                .help("Off by default — uses HeiGIT OpenRouteService geocoding only")

            Text("HeiGIT API Key")
                .font(RFFont.caption)
                .foregroundStyle(.secondary)

            SecureField("OpenRouteService API key", text: $viewModel.orsAPIKeyDraft)
                .textFieldStyle(GlassTextFieldStyle())
                .onSubmit { viewModel.persistORSAPIKey() }

            Button("Save API Key") {
                viewModel.persistORSAPIKey()
            }
            .buttonStyle(.borderless)

            Text("OpenWeather API Key")
                .font(RFFont.caption)
                .foregroundStyle(.secondary)

            SecureField("OpenWeather API key", text: $viewModel.openWeatherAPIKeyDraft)
                .textFieldStyle(GlassTextFieldStyle())
                .onSubmit { viewModel.persistOpenWeatherAPIKey() }

            Button("Save OpenWeather Key") {
                viewModel.persistOpenWeatherAPIKey()
            }
            .buttonStyle(.borderless)
        }
    }
}

// MARK: - Attribution

struct OSMAttributionFooter: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("© OpenStreetMap contributors")
                .font(.caption2)
            Text("Search data © HeiGIT OpenRouteService / OSM Foundation")
                .font(.caption2)
            Link("OpenStreetMap copyright", destination: URL(string: "https://www.openstreetmap.org/copyright")!)
                .font(.caption2)
        }
        .foregroundStyle(.secondary)
        .padding(.top, RFSpacing.sm)
    }
}

private struct HGVModeBadge: View {
    var body: some View {
        Label("HGV Mode Active", systemImage: "truck.box.fill")
            .font(RFFont.caption)
            .foregroundStyle(RFColor.hazard)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(RFColor.hazard.opacity(0.15), in: Capsule())
    }
}
