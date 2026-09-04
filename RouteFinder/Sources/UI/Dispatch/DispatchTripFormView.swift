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
                orgSection
                vehicleSection
                stopsSection
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
        .task {
            await viewModel.refreshCatalog()
            viewModel.startPolling()
        }
        .onDisappear {
            viewModel.stopPolling()
        }
        .onChange(of: viewModel.selectedOrgId) { _, _ in
            Task { await viewModel.orgSelectionChanged() }
        }
        .onChange(of: viewModel.draft) { _, _ in
            Task { await viewModel.refreshRoutePreview() }
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: RFSpacing.xs) {
            Text("Fleet dispatch")
                .font(RFFont.sectionTitle)
            Text("Company break windows are planning aids only — the digital tachograph remains the legal record.")
                .font(RFFont.caption)
                .foregroundStyle(.secondary)
        }
        .glassPanel(cornerRadius: 14)
        .padding(RFSpacing.sm)
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
                Picker("Vehicle", selection: $viewModel.selectedVehicleId) {
                    ForEach(viewModel.vehicles, id: \.id) { vehicle in
                        Text(vehicleLabel(vehicle)).tag(Optional(vehicle.id))
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
    }

    private var stopsSection: some View {
        VStack(alignment: .leading, spacing: RFSpacing.sm) {
            HStack {
                Text("Stops")
                    .font(RFFont.sectionTitle)
                Spacer()
                if viewModel.draft.stops.count < 5 {
                    Button("Add") {
                        viewModel.draft.stops.append(DispatchStopDraft())
                    }
                    .controlSize(.small)
                }
            }
            ForEach(Array(viewModel.draft.stops.enumerated()), id: \.element.id) { index, _ in
                stopRow(index: index)
            }
            HStack(spacing: RFSpacing.sm) {
                presetButton("Felixstowe", label: "Felixstowe Port", lat: "51.9542", lon: "1.3511", index: 0)
                presetButton("Midlands", label: "Midlands Hub", lat: "52.4862", lon: "-1.8904", index: 1)
                presetButton("Manchester", label: "Manchester Depot", lat: "53.4808", lon: "-2.2426", index: 2)
            }
            Button("Load UK demo template") {
                viewModel.draft = DispatchTripDraft.ukDemoTemplate()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
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
            .disabled(viewModel.isPushing || viewModel.selectedVehicleId == nil)
        }
    }

    private func vehicleLabel(_ vehicle: FleetVehicle) -> String {
        if let plate = vehicle.registrationPlate, !plate.isEmpty {
            return "\(vehicle.label) (\(plate))"
        }
        return vehicle.label
    }
}
