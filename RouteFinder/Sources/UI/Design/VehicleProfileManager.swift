import Contracts
import DataLayer
import RouteController
import SwiftUI

/// Manages HGV vehicle dimensions, presets, and saved profiles.
public struct VehicleProfileManager: View {
    @Bindable var viewModel: RouteViewModel
    @State private var savedProfiles: [VehicleProfile] = []
    @State private var profileName = ""
    @State private var saveError: String?
    private let profileStore = VehicleProfileStore()

    public init(viewModel: RouteViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: RFSpacing.lg) {
                registrationSection
                presetSection
                dimensionsSection
                physicsSection
                legalSection
                saveSection
            }
            .padding(RFSpacing.lg)
            .padding(.bottom, RFSpacing.xl)
        }
        .navigationTitle("Vehicle Profile")
        .task { await reloadProfiles() }
    }

    private var registrationSection: some View {
        VStack(alignment: .leading, spacing: RFSpacing.sm) {
            Text("Vehicle Registration")
                .font(RFFont.sectionTitle)

            HStack(spacing: RFSpacing.sm) {
                TextField("Vehicle Reg", text: $viewModel.vehicleRegistration)
                    .textFieldStyle(GlassTextFieldStyle())
#if os(iOS)
                    .textInputAutocapitalization(.characters)
#endif
                    .onChange(of: viewModel.vehicleRegistration) { _, newValue in
                        let upperFiltered = newValue.uppercased()
                            .filter { $0.isLetter || $0.isNumber || $0.isWhitespace }
                        let formatted = RegistrationNormalizer.formatForDisplay(upperFiltered)
                        if viewModel.vehicleRegistration != formatted {
                            viewModel.vehicleRegistration = formatted
                        }
                        viewModel.scheduleVehicleWorkspacePersist()
                    }
                Button("Lookup") {
                    Task { await viewModel.applyRegistrationLookup() }
                }
                .modifier(GlassButton())
                .disabled(viewModel.registrationLookupInProgress)
            }

            if viewModel.registrationLookupInProgress {
                ProgressView("Looking up registration…")
                    .font(RFFont.caption)
            }

            if let error = viewModel.registrationLookupError {
                Text(error)
                    .font(RFFont.caption)
                    .foregroundStyle(.red)
            }

            if !viewModel.vehicleTypeLabel.isEmpty {
                HStack(spacing: RFSpacing.sm) {
                    profileChip("Type: \(viewModel.vehicleTypeLabel)")
                    if !viewModel.vehicleAxleCount.isEmpty {
                        profileChip("Axles: \(viewModel.vehicleAxleCount)")
                    }
                }
            }

            if viewModel.registrationSource == .fallbackSynthesized
                || viewModel.registrationSource == .unverified
                || viewModel.registrationSource == .transientHeuristic {
                Text("Unverified — manual check recommended")
                    .font(RFFont.caption)
                    .foregroundStyle(.orange)
                    .padding(.horizontal, RFSpacing.sm)
                    .padding(.vertical, RFSpacing.xs)
                    .background(.orange.opacity(0.12), in: Capsule())
            }

            Picker("Vehicle class override", selection: $viewModel.vehicleClassOverride) {
                Text("Auto").tag(VehicleProfileClass?.none)
                ForEach(VehicleProfileClass.allCases, id: \.self) { vehicleClass in
                    Text(vehicleClass.displayName).tag(Optional(vehicleClass))
                }
            }
            .pickerStyle(.menu)
        }
    }

    private func profileChip(_ title: String) -> some View {
        Text(title)
            .font(RFFont.caption)
            .padding(.horizontal, RFSpacing.sm)
            .padding(.vertical, 6)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay(Capsule().strokeBorder(.white.opacity(0.2), lineWidth: 0.5))
    }

    private var presetSection: some View {
        VStack(alignment: .leading, spacing: RFSpacing.sm) {
            Text("Presets")
                .font(RFFont.sectionTitle)

            HStack(spacing: RFSpacing.sm) {
                presetChip("UK Artic", profile: .ukArtic)
                presetChip("Rigid 26t", profile: .ukRigid26t)
                presetChip("Custom", profile: .default)
            }
        }
    }

    private func presetChip(_ title: String, profile: VehicleProfile) -> some View {
        Button(title) {
            viewModel.applyProfile(profile)
        }
        .buttonStyle(.borderless)
        .padding(.horizontal, RFSpacing.sm)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().strokeBorder(.white.opacity(0.2), lineWidth: 0.5))
    }

    private var dimensionsSection: some View {
        VStack(alignment: .leading, spacing: RFSpacing.sm) {
            Text("Dimensions")
                .font(RFFont.sectionTitle)

            dimensionRow(icon: "arrow.up.and.down", label: "Height (m)", text: $viewModel.vehicleHeight)
            dimensionRow(icon: "arrow.left.and.right", label: "Width (m)", text: $viewModel.vehicleWidth)
            dimensionRow(icon: "ruler", label: "Length (m)", text: $viewModel.vehicleLength)
            dimensionRow(icon: "scalemass", label: "Weight (t)", text: $viewModel.vehicleWeight)
        }
    }

    private var physicsSection: some View {
        VStack(alignment: .leading, spacing: RFSpacing.sm) {
            Text("Physics")
                .font(RFFont.sectionTitle)

            HStack(spacing: RFSpacing.sm) {
                Image(systemName: "engine.combustion")
                    .frame(width: 22)
                    .foregroundStyle(.secondary)
                TextField("Engine power (HP)", text: $viewModel.vehicleEnginePowerHP)
                    .textFieldStyle(GlassTextFieldStyle())
                    .onChange(of: viewModel.vehicleEnginePowerHP) { _, _ in
                        Task { await viewModel.refreshSimulationPowerFromSidebar() }
                    }
            }

            dimensionRow(icon: "circle.circle", label: "Axle weight (t)", text: $viewModel.vehicleAxleWeight, field: .axleWeight)
            dimensionRow(icon: "arrow.triangle.turn.up.right.diamond", label: "Turn radius (m)", text: $viewModel.vehicleTurningRadius, field: .turningRadius)
            dimensionRow(icon: "road.lanes", label: "Ground clearance (m)", text: $viewModel.vehicleGroundClearance, field: .groundClearance)

            Text("Lookup fills dimensions and physics from the registry (or class defaults). Edit HP for HGV overrides.")
                .font(RFFont.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var legalSection: some View {
        VStack(alignment: .leading, spacing: RFSpacing.sm) {
            Text("Legal & Routing")
                .font(RFFont.sectionTitle)

            Toggle("HGV / Truck Mode", isOn: $viewModel.isHGVMode)
                .tint(RFColor.hazard)
                .onChange(of: viewModel.isHGVMode) { _, enabled in
                    if enabled, viewModel.vehicleHeight.isEmpty { viewModel.applyHGVPreset() }
                    viewModel.scheduleVehicleWorkspacePersist()
                    Task { await viewModel.recalculateIfReady() }
                }

            if viewModel.isHGVMode {
                Toggle("Avoid residential roads", isOn: $viewModel.avoidResidential)
                    .onChange(of: viewModel.avoidResidential) { _, _ in
                        viewModel.scheduleVehicleWorkspacePersist()
                        Task { await viewModel.recalculateIfReady() }
                    }
            }

            Picker("Hazmat class", selection: $viewModel.hazmatClass) {
                Text("None").tag(HazmatClass?.none)
                ForEach(HazmatClass.allCases.filter { $0 != .none }, id: \.self) { cls in
                    Text(cls.rawValue).tag(Optional(cls))
                }
            }
            .onChange(of: viewModel.hazmatClass) { _, _ in
                viewModel.scheduleVehicleWorkspacePersist()
            }

            Picker("Emission class", selection: $viewModel.emissionClass) {
                Text("Not set").tag(EmissionClass?.none)
                ForEach(EmissionClass.allCases, id: \.self) { cls in
                    Text(cls.rawValue.uppercased()).tag(Optional(cls))
                }
            }
            .onChange(of: viewModel.emissionClass) { _, _ in
                viewModel.scheduleVehicleWorkspacePersist()
            }
        }
    }

    private var saveSection: some View {
        VStack(alignment: .leading, spacing: RFSpacing.sm) {
            Text("Saved Profiles")
                .font(RFFont.sectionTitle)

            TextField("Profile name", text: $profileName)
                .textFieldStyle(GlassTextFieldStyle())

            if let saveError {
                Text(saveError)
                    .font(RFFont.caption)
                    .foregroundStyle(.red)
            }

            HStack {
                Button("Save") {
                    Task { await saveProfile() }
                }
                .modifier(GlassButton())

                Button("Duplicate") {
                    profileName = (viewModel.activeProfileName ?? "Custom") + " Copy"
                }
                .buttonStyle(.borderless)
            }

            if !savedProfiles.isEmpty {
                ForEach(savedProfiles, id: \.savedProfileName) { profile in
                    HStack {
                        Button(profile.savedProfileName ?? "Unnamed") {
                            viewModel.applyProfile(profile)
                        }
                        .buttonStyle(.borderless)
                        Spacer()
                        Button(role: .destructive) {
                            Task { await deleteProfile(named: profile.savedProfileName ?? "") }
                        } label: {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.borderless)
                    }
                }
            }
        }
    }

    private func dimensionRow(
        icon: String,
        label: String,
        text: Binding<String>,
        field: VehiclePhysicsField? = nil
    ) -> some View {
        HStack(spacing: RFSpacing.sm) {
            Image(systemName: icon)
                .frame(width: 22)
                .foregroundStyle(.secondary)
            if let field {
                TextField(label, text: text, prompt: Text(viewModel.physicsPlaceholder(for: field)).foregroundStyle(.secondary))
                    .textFieldStyle(GlassTextFieldStyle())
                    .onChange(of: text.wrappedValue) { _, newValue in
                        viewModel.markPhysicsFieldEdited(field, text: newValue)
                        viewModel.scheduleVehicleWorkspacePersist()
                    }
            } else {
                TextField(label, text: text)
                    .textFieldStyle(GlassTextFieldStyle())
                    .onChange(of: text.wrappedValue) { _, _ in
                        viewModel.scheduleVehicleWorkspacePersist()
                    }
            }
        }
    }

    private func reloadProfiles() async {
        savedProfiles = await profileStore.loadProfiles()
    }

    private func saveProfile() async {
        saveError = nil
        let trimmed = profileName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            saveError = VehicleProfileStoreError.missingName.errorDescription
            return
        }
        var profile = viewModel.currentVehicleProfile()
        profile = VehicleProfile(
            height: profile.height,
            weight: profile.weight,
            width: profile.width,
            length: profile.length,
            axleWeight: profile.axleWeight,
            groundClearance: profile.groundClearance,
            turningRadius: profile.turningRadius,
            hazmatClass: profile.hazmatClass,
            emissionClass: profile.emissionClass,
            savedProfileName: trimmed
        )
        do {
            try await profileStore.save(profile)
            viewModel.activeProfileName = trimmed
            await reloadProfiles()
        } catch {
            saveError = error.localizedDescription
        }
    }

    private func deleteProfile(named name: String) async {
        guard !name.isEmpty else { return }
        try? await profileStore.delete(named: name)
        await reloadProfiles()
    }
}
