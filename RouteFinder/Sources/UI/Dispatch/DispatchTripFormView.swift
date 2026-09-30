import Contracts
import SwiftUI

/// Dispatch sidebar: org/vehicle selection, stops, break window, push action.
struct DispatchTripFormView: View {
    @Bindable var viewModel: DispatchViewModel
    @FocusState private var focusedStopId: UUID?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: RFSpacing.lg) {
                headerSection
                proxyStatusSection
                orgSection
                vehicleSection
                stopsSection
                jobBriefSection
                breakSection
                actionsSection
                if let message = viewModel.statusMessage {
                    Text(message)
                        .font(RFFont.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(RFSpacing.lg)
        }
        .navigationTitle("Dispatch")
        // Catalog + polling owned by DispatchConsoleView — avoid duplicate .task lifecycle here.
        .onChange(of: viewModel.selectedOrgId) { _, _ in
            Task { await viewModel.orgSelectionChanged() }
        }
        .onChange(of: viewModel.draft) { _, _ in
            Task { await viewModel.refreshRoutePreview() }
        }
    }

    private var headerSection: some View {
        DisclosureGroup {
            Text("Company break windows are planning aids only — the digital tachograph remains the legal record.")
                .font(RFFont.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, RFSpacing.xs)
        } label: {
            Text("Fleet dispatch")
                .font(RFFont.sectionTitle)
        }
        .glassPanel(cornerRadius: 14)
        .padding(RFSpacing.sm)
    }

    @ViewBuilder
    private var proxyStatusSection: some View {
        if viewModel.fleetServerHealthOk == true,
           let status = viewModel.fleetProxyStatus {
            DisclosureGroup {
                VStack(alignment: .leading, spacing: RFSpacing.xs) {
                    ForEach(Array(status.summaryLines.enumerated()), id: \.offset) { _, line in
                        Text(line)
                            .font(RFFont.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if let warning = status.nearCapWarning {
                        Text(warning)
                            .font(RFFont.caption.weight(.semibold))
                            .foregroundStyle(.orange)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, RFSpacing.xs)
            } label: {
                Text("Fleet proxy")
                    .font(RFFont.sectionTitle)
            }
            .glassPanel(cornerRadius: 14)
            .padding(RFSpacing.sm)
            .accessibilityIdentifier("dispatchProxyStatusPanel")
        }
    }

    private var orgSection: some View {
        VStack(alignment: .leading, spacing: RFSpacing.sm) {
            Text("Organisation")
                .font(RFFont.sectionTitle)
            if viewModel.orgs.isEmpty {
                Text("No org yet — bootstrap demo fleet below.")
                    .font(RFFont.caption)
                    .foregroundStyle(.secondary)
            } else {
                Picker("Organisation", selection: $viewModel.selectedOrgId) {
                    ForEach(viewModel.orgs, id: \.id) { org in
                        Text(org.name).tag(Optional(org.id))
                    }
                }
            }
        }
        .glassPanel(cornerRadius: 14)
        .padding(RFSpacing.sm)
    }

    private var vehicleSection: some View {
        VStack(alignment: .leading, spacing: RFSpacing.sm) {
            Text("Vehicle")
                .font(RFFont.sectionTitle)
            if viewModel.vehicles.isEmpty {
                Text("Register a vehicle via demo bootstrap.")
                    .font(RFFont.caption)
                    .foregroundStyle(.secondary)
            } else {
                TextField("Filter vehicles…", text: $viewModel.vehicleFilterQuery)
                    .textFieldStyle(GlassTextFieldStyle())
                Picker("Roster mode", selection: $viewModel.vehiclePickerMode) {
                    Text("All").tag(DispatchRosterPickerMode.all)
                    Text("Hide offline").tag(DispatchRosterPickerMode.hideOffline)
                    Text("Defects only").tag(DispatchRosterPickerMode.defectsOnly)
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("dispatchVehiclePickerMode")
                if viewModel.filteredVehicles.isEmpty {
                    Text("No vehicles match filter")
                        .font(RFFont.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Picker("Vehicle", selection: $viewModel.selectedVehicleId) {
                        ForEach(viewModel.filteredVehicles, id: \.id) { vehicle in
                            Text(vehicleLabel(vehicle)).tag(Optional(vehicle.id))
                        }
                    }
                }
                if let vehicleId = viewModel.selectedVehicleId {
                    let label = viewModel.vehicles.first(where: { $0.id == vehicleId }).map(vehicleLabel) ?? "Vehicle"
                    VehiclePairingQRView(vehicleId: vehicleId, vehicleLabel: label)
                }
            }
        }
        .glassPanel(cornerRadius: 14)
        .padding(RFSpacing.sm)
        .onChange(of: viewModel.vehicleFilterQuery) { _, _ in
            Task { await viewModel.refreshRoster() }
        }
    }

    private var stopsSection: some View {
        VStack(alignment: .leading, spacing: RFSpacing.sm) {
            HStack {
                Text("Draft stops")
                    .font(RFFont.sectionTitle)
                Spacer()
                if viewModel.draft.stops.count < 5 {
                    Button("Add") {
                        viewModel.draft.stops.append(DispatchStopDraft())
                    }
                    .controlSize(.small)
                }
            }
            Text("Edit here, then Push to update the driver’s active trip.")
                .font(.caption2)
                .foregroundStyle(.secondary)
            ForEach(Array(viewModel.draft.stops.enumerated()), id: \.element.id) { index, _ in
                stopRow(index: index)
            }
            HStack(spacing: RFSpacing.sm) {
                presetButton("Norwich", label: "Norwich", lat: "52.6309", lon: "1.2974", index: 0)
                presetButton("King's Lynn", label: "King's Lynn", lat: "52.7519", lon: "0.3955", index: 1)
            }
            Button("Load Norwich → King's Lynn") {
                viewModel.draft = DispatchTripDraft.norfolkDemoCorridor()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .accessibilityIdentifier("dispatchLoadNorfolkCorridor")
            Button("Load UK long-haul template") {
                viewModel.draft = DispatchTripDraft.ukDemoTemplate()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .accessibilityIdentifier("dispatchLoadLongHaulTemplate")
        }
        .glassPanel(cornerRadius: 14)
        .padding(RFSpacing.sm)
    }

    private func stopRow(index: Int) -> some View {
        let stopId = viewModel.draft.stops[index].id
        return VStack(alignment: .leading, spacing: RFSpacing.xs) {
            HStack {
                Text("Stop \(index + 1)")
                    .font(RFFont.caption.weight(.semibold))
                Spacer()
                if viewModel.draft.stops.count > 2 {
                    Button(role: .destructive) {
                        viewModel.draft.stops.remove(at: index)
                    } label: {
                        Image(systemName: "minus.circle")
                    }
                    .buttonStyle(.plain)
                }
            }
            LocationSearchField(
                placeholder: stopPlaceholder(index: index),
                text: $viewModel.draft.stops[index].label,
                focusTag: stopId,
                focusedWaypointID: $focusedStopId,
                resolutionStatus: viewModel.resolutionStatus(for: stopId),
                feedback: viewModel.feedback(for: stopId),
                suggestions: viewModel.suggestions(for: stopId),
                onQueryChange: { viewModel.updateSearchSuggestions(for: stopId, query: $0) },
                onPinTap: {},
                onSelect: { suggestion in
                    Task { await viewModel.applySuggestion(suggestion, for: stopId) }
                }
            )
            if viewModel.resolutionStatus(for: stopId) == .resolved {
                Text("\(viewModel.draft.stops[index].latitude), \(viewModel.draft.stops[index].longitude)")
                    .font(RFFont.caption)
                    .foregroundStyle(.secondary)
            }
            Toggle(
                "Time window",
                isOn: Binding(
                    get: {
                        viewModel.draft.stops[index].earliestArrival != nil
                            || viewModel.draft.stops[index].latestArrival != nil
                    },
                    set: { enabled in
                        if enabled {
                            if viewModel.draft.stops[index].earliestArrival == nil {
                                viewModel.draft.stops[index].earliestArrival = Date()
                            }
                            if viewModel.draft.stops[index].latestArrival == nil {
                                viewModel.draft.stops[index].latestArrival = Date().addingTimeInterval(7200)
                            }
                        } else {
                            viewModel.draft.stops[index].earliestArrival = nil
                            viewModel.draft.stops[index].latestArrival = nil
                        }
                    }
                )
            )
            .font(RFFont.caption)
            if viewModel.draft.stops[index].earliestArrival != nil || viewModel.draft.stops[index].latestArrival != nil {
                DatePicker(
                    "Earliest",
                    selection: Binding(
                        get: { viewModel.draft.stops[index].earliestArrival ?? Date() },
                        set: { viewModel.draft.stops[index].earliestArrival = $0 }
                    )
                )
                DatePicker(
                    "Latest",
                    selection: Binding(
                        get: { viewModel.draft.stops[index].latestArrival ?? Date().addingTimeInterval(7200) },
                        set: { viewModel.draft.stops[index].latestArrival = $0 }
                    )
                )
            }
        }
    }

    private func stopPlaceholder(index: Int) -> String {
        switch index {
        case 0: return "Origin — search address"
        case viewModel.draft.stops.count - 1: return "Destination — search address"
        default: return "Stop \(index + 1) — search address"
        }
    }

    private func presetButton(
        _ title: String,
        label: String,
        lat: String,
        lon: String,
        index: Int
    ) -> some View {
        Button(title) {
            while viewModel.draft.stops.count <= index {
                viewModel.draft.stops.append(DispatchStopDraft())
            }
            viewModel.draft.stops[index].label = label
            viewModel.draft.stops[index].latitude = lat
            viewModel.draft.stops[index].longitude = lon
        }
        .buttonStyle(.bordered)
        .controlSize(.mini)
    }

    private var jobBriefSection: some View {
        VStack(alignment: .leading, spacing: RFSpacing.sm) {
            Text("Job brief")
                .font(RFFont.sectionTitle)
            Text("Optional weight and ADR travel with the push so the driver profile and ORS request match the load.")
                .font(RFFont.caption)
                .foregroundStyle(.secondary)
            TextField("Gross weight (kg)", text: $viewModel.draft.grossWeightKgText)
                .textFieldStyle(GlassTextFieldStyle())
            TextField("ADR class (e.g. 3)", text: $viewModel.draft.adrClassText)
                .textFieldStyle(GlassTextFieldStyle())
            Toggle("Auto find route on driver", isOn: $viewModel.draft.autoFindRoute)
        }
        .glassPanel(cornerRadius: 14)
        .padding(RFSpacing.sm)
    }

    private var breakSection: some View {
        VStack(alignment: .leading, spacing: RFSpacing.sm) {
            Text("Company break window")
                .font(RFFont.sectionTitle)
            TextField("Break label", text: $viewModel.draft.breakLabel)
                .textFieldStyle(GlassTextFieldStyle())
            DatePicker("Opens", selection: $viewModel.draft.breakWindowStart)
            DatePicker("Closes", selection: $viewModel.draft.breakWindowEnd)
            Stepper(
                "Duration: \(viewModel.draft.breakDurationMinutes) min",
                value: $viewModel.draft.breakDurationMinutes,
                in: 15...90,
                step: 15
            )
        }
        .glassPanel(cornerRadius: 14)
        .padding(RFSpacing.sm)
    }

    private var actionsSection: some View {
        VStack(spacing: RFSpacing.sm) {
            Button("Bootstrap demo fleet") {
                Task { await viewModel.bootstrapDemoFleet() }
            }
            .buttonStyle(.bordered)
            .disabled(viewModel.isLoading)

            Button {
                Task { await viewModel.pushDraftTrip() }
            } label: {
                if viewModel.isPushing {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Text("Push to driver")
                }
            }
            .modifier(GlassButton())
            .disabled(viewModel.isPushing || !viewModel.canPushTrip)

            if viewModel.isPushBlockedByFleetHealth {
                Text("Connect to the fleet server — health pill must show Connected (not Local disk / Offline / Auth failed).")
                    .font(RFFont.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("dispatchPushFleetHealthHint")
            }

            if viewModel.needsFleetAPIKeyPaste {
                VStack(alignment: .leading, spacing: RFSpacing.xs) {
                    Text("Paste the same secret as server `--api-key` (web Bearer / driver wizard).")
                        .font(RFFont.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    SecureField("Fleet API key", text: $viewModel.fleetAPIKeyDraft)
                        .textFieldStyle(.roundedBorder)
                        .accessibilityIdentifier("dispatchFleetAPIKey")
                    Button {
                        Task { await viewModel.saveFleetAPIKeyAndReprobe() }
                    } label: {
                        if viewModel.isSavingFleetAPIKey {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Text("Save fleet API key")
                        }
                    }
                    .buttonStyle(.bordered)
                    .disabled(viewModel.isSavingFleetAPIKey)
                    .accessibilityIdentifier("dispatchSaveFleetAPIKey")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func vehicleLabel(_ vehicle: FleetVehicle) -> String {
        if let plate = vehicle.registrationPlate, !plate.isEmpty {
            return "\(vehicle.label) (\(plate))"
        }
        return vehicle.label
    }
}
