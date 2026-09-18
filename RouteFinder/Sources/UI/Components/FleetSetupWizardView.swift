import Contracts
import SwiftUI

/// Guided first-run / re-entry flow for pairing a driver device to LAN or hosted fleet.
struct FleetSetupWizardView: View {
    @Bindable var viewModel: RouteViewModel
    @Environment(\.dismiss) private var dismiss

    private enum Step: Int, CaseIterable {
        case enableRemote
        case discover
        case test
        case vehicle
        case done
    }

    @State private var step: Step = .enableRemote
    @State private var showScanner = false
    @State private var connectionKind: FleetConnectionKind = FleetWorkspaceSettings.loadFleetConnectionKind()

    private var isHosted: Bool { connectionKind == .hosted }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: RFSpacing.lg) {
                progressHeader
                stepContent
                Spacer(minLength: 0)
                navigationRow
            }
            .padding(RFSpacing.lg)
            .navigationTitle("Fleet setup")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            #if os(iOS)
            .sheet(isPresented: $showScanner) {
                FleetVehicleQRScannerView { vehicleId in
                    viewModel.fleetVehicleIdText = vehicleId.uuidString
                    viewModel.saveFleetVehicleIdFromSettings()
                    step = .done
                }
            }
            #endif
        }
        #if os(macOS)
        .frame(minWidth: 480, minHeight: 420)
        #endif
    }

    private var progressHeader: some View {
        VStack(alignment: .leading, spacing: RFSpacing.xs) {
            Text("Step \(step.rawValue + 1) of \(Step.allCases.count)")
                .font(RFFont.caption)
                .foregroundStyle(.secondary)
            Text(title(for: step))
                .font(RFFont.sectionTitle)
            Text(subtitle(for: step))
                .font(RFFont.body)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var stepContent: some View {
        switch step {
        case .enableRemote:
            Toggle("Use remote fleet server", isOn: $viewModel.useRemoteFleetServer)
                .onChange(of: viewModel.useRemoteFleetServer) { _, _ in
                    viewModel.saveFleetServerURLFromSettings()
                }
            Picker("Connection", selection: $connectionKind) {
                Text("Office LAN").tag(FleetConnectionKind.lan)
                Text("Hosted (HTTPS)").tag(FleetConnectionKind.hosted)
            }
            .pickerStyle(.segmented)
            .onChange(of: connectionKind) { _, kind in
                FleetWorkspaceSettings.saveFleetConnectionKind(kind)
            }
            Text(
                isHosted
                    ? "Use a hosted fleet URL from your operator (https://…). Works on cellular — no office Wi‑Fi required."
                    : "Turn this on so trip pushes from the office reach this phone over Wi‑Fi."
            )
            .font(RFFont.caption)
            .foregroundStyle(.secondary)

        case .discover:
            TextField(
                isHosted ? "Hosted fleet URL (https://…)" : "Fleet server URL",
                text: $viewModel.fleetServerURLText
            )
                .textFieldStyle(GlassTextFieldStyle())
                #if os(iOS)
                .textInputAutocapitalization(.never)
                .keyboardType(.URL)
                #endif
            SecureField(
                isHosted ? "Org bearer token" : "Fleet API key (optional)",
                text: $viewModel.fleetServerAPIKeyText
            )
                .textFieldStyle(GlassTextFieldStyle())
            if isHosted {
                Text("Example: https://fleet.yourdomain.com — paste the org token from your operator. Never paste the operator ORS key.")
                    .font(RFFont.caption)
                    .foregroundStyle(.secondary)
            } else {
                Button("Discover on LAN") {
                    Task { await viewModel.discoverFleetServersOnLAN() }
                }
                .buttonStyle(.bordered)
                .disabled(viewModel.isDiscoveringFleetServers)

                if let status = viewModel.fleetDiscoveryStatus {
                    Text(status).font(RFFont.caption).foregroundStyle(.secondary)
                }
                ForEach(viewModel.discoveredFleetServers) { server in
                    Button {
                        viewModel.applyDiscoveredFleetServer(server)
                    } label: {
                        VStack(alignment: .leading) {
                            Text(server.displayName)
                            Text(server.baseURL.absoluteString)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.borderless)
                }
            }

        case .test:
            Button("Test connection") {
                Task { await viewModel.testFleetServerConnection() }
            }
            .buttonStyle(.borderedProminent)
            if let status = viewModel.fleetServerConnectionStatus {
                Text(status)
                    .font(RFFont.caption)
                    .foregroundStyle(status.contains("Connected") ? .green : .secondary)
            }
            Text(
                isHosted
                    ? "Hosted gateway must respond on /health. Routing keys stay on the server — use your org bearer token only."
                    : "Same Wi‑Fi as the dispatch Mac. Routing API keys stay on the server when ORS proxy is enabled."
            )
            .font(RFFont.caption)
            .foregroundStyle(.secondary)

        case .vehicle:
            TextField("Vehicle UUID", text: $viewModel.fleetVehicleIdText)
                .textFieldStyle(GlassTextFieldStyle())
                #if os(iOS)
                .textInputAutocapitalization(.never)
                #endif
            Text("Scan the QR shown in Mac Dispatch or web dispatch, or paste the UUID.")
                .font(RFFont.caption)
                .foregroundStyle(.secondary)
            #if os(iOS)
            Button("Scan QR") { showScanner = true }
                .buttonStyle(.bordered)
            #endif
            Button("Save vehicle id") {
                viewModel.saveFleetVehicleIdFromSettings()
            }
            .buttonStyle(.bordered)

        case .done:
            Label("You're paired", systemImage: "checkmark.circle.fill")
                .font(RFFont.sectionTitle)
                .foregroundStyle(.green)
            Text(
                isHosted
                    ? "When dispatch pushes a trip, you'll get a toast within a few seconds — even on cellular. Find route → Rehearse → Start as usual. Cloud routing uses the hosted gateway key — no HeiGIT key needed on this device."
                    : "When dispatch pushes a trip, you'll get a toast within a few seconds. Find route → Rehearse → Start as usual. Cloud routing uses the fleet server key when configured — no HeiGIT key needed on this device."
            )
            .font(RFFont.body)
            Button("Check for dispatch now") {
                Task { await viewModel.pollAndApplyFleetDispatch() }
            }
            .buttonStyle(.bordered)
        }
    }

    private var navigationRow: some View {
        HStack {
            if step != .enableRemote {
                Button("Back") { move(-1) }
                    .buttonStyle(.bordered)
            }
            Spacer()
            if step == .done {
                Button("Finish") {
                    viewModel.saveFleetServerURLFromSettings()
                    viewModel.saveFleetVehicleIdFromSettings()
                    FleetWorkspaceSettings.saveFleetConnectionKind(connectionKind)
                    dismiss()
                }
                .modifier(GlassButton())
            } else {
                Button("Next") {
                    if step == .enableRemote {
                        viewModel.useRemoteFleetServer = true
                        FleetWorkspaceSettings.saveFleetConnectionKind(connectionKind)
                        viewModel.saveFleetServerURLFromSettings()
                    }
                    if step == .discover {
                        viewModel.saveFleetServerURLFromSettings()
                    }
                    if step == .vehicle {
                        viewModel.saveFleetVehicleIdFromSettings()
                    }
                    move(1)
                }
                .modifier(GlassButton())
                .disabled(!canAdvance)
            }
        }
    }

    private var canAdvance: Bool {
        switch step {
        case .enableRemote:
            return true
        case .discover:
            let text = viewModel.fleetServerURLText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty, let url = URL(string: text), let scheme = url.scheme?.lowercased() else {
                return false
            }
            if isHosted { return scheme == "https" }
            return scheme == "http" || scheme == "https"
        case .test:
            return (viewModel.fleetServerConnectionStatus ?? "").contains("Connected")
                || !viewModel.fleetServerURLText.isEmpty
        case .vehicle:
            return UUID(uuidString: viewModel.fleetVehicleIdText.trimmingCharacters(in: .whitespacesAndNewlines)) != nil
        case .done:
            return true
        }
    }

    private func move(_ delta: Int) {
        let next = step.rawValue + delta
        guard let newStep = Step(rawValue: next) else { return }
        step = newStep
    }

    private func title(for step: Step) -> String {
        switch step {
        case .enableRemote: return "Enable fleet sync"
        case .discover: return isHosted ? "Enter hosted URL" : "Find the office server"
        case .test: return "Confirm connection"
        case .vehicle: return "Pair this vehicle"
        case .done: return "Ready"
        }
    }

    private func subtitle(for step: Step) -> String {
        switch step {
        case .enableRemote:
            return isHosted
                ? "Connect this device to your operator’s hosted fleet gateway."
                : "Connect this device to RouteFinderFleetServer on the office LAN."
        case .discover:
            return isHosted
                ? "Paste the HTTPS base URL (e.g. https://fleet.yourdomain.com) and org bearer token."
                : "Use Bonjour discovery or paste the Mac’s LAN URL (e.g. http://192.168.1.10:8080)."
        case .test: return "Make sure /health responds before pairing a vehicle."
        case .vehicle: return "Each truck has one UUID from the dispatch console."
        case .done: return "Setup complete for this device."
        }
    }
}
