#if os(iOS)
import Contracts
import MapLibreUI
import RouteController
import SwiftUI

private let iosMapPeekDetent = PresentationDetent.fraction(0.12)

/// Maps-style iOS map chrome: compact top search, bottom detent sheet, consolidated toolbar.
struct IOSMapChrome: View {
    @Bindable var viewModel: RouteViewModel
    @Binding var isRouteSheetVisible: Bool
    var hideRouteSheet: Bool = false
    var onPresentModal: (IOSModal) -> Void
    var onOpenWalkaround: () -> Void = {}

    @AppStorage("dismissCloudRoutingBanner") private var isCloudBannerDismissed = false
    @State private var sheetPhase: IOSRouteSheetPhase = .peek
    @State private var selectedDetent: PresentationDetent = iosMapPeekDetent
    @State private var isBottomSheetPresented = true
    @State private var isDetailExpanded = false
    @State private var isKeyboardVisible = false
    @State private var pendingModal: IOSModal?
    @State private var pendingFocusWaypointID: UUID?
    @State private var showAlertOverflow = false
    @State private var refitMapTask: Task<Void, Never>?

    private static let peekDetent = iosMapPeekDetent

    private var routeSheetPresented: Binding<Bool> {
        Binding(
            get: { isBottomSheetPresented && !hideRouteSheet },
            set: { newValue in
                if !hideRouteSheet {
                    isBottomSheetPresented = newValue
                }
            }
        )
    }

    var body: some View {
        Color.clear
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .allowsHitTesting(false)
            .onChange(of: viewModel.routeDetailCollapseTick) { _, _ in
                isDetailExpanded = false
            }
            .overlay(alignment: .top) {
                topChrome
                    .padding(.horizontal, RFSpacing.md)
                    .safeAreaPadding(.top, RFSpacing.sm)
                    .allowsHitTesting(true)
            }
            .overlay(alignment: .bottomTrailing) {
                IOSMapToolbar(
                    viewModel: viewModel,
                    onOpenSettings: { requestModal(.settings) },
                    onOpenProfile: { requestModal(.profile) },
                    onOpenWalkaround: onOpenWalkaround
                )
                .padding(.trailing, RFSpacing.md)
                .padding(.bottom, toolbarBottomPadding)
                .safeAreaPadding(.bottom)
                .allowsHitTesting(true)
            }
            .sheet(isPresented: routeSheetPresented) {
                IOSRouteSheet(
                    viewModel: viewModel,
                    phase: sheetPhase,
                    isDetailExpanded: $isDetailExpanded,
                    selectedDetent: $selectedDetent,
                    isKeyboardVisible: $isKeyboardVisible,
                    pendingFocusWaypointID: $pendingFocusWaypointID,
                    showAlertOverflow: $showAlertOverflow,
                    onPeekTap: {
                        if viewModel.result != nil {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                sheetPhase = .results
                                selectedDetent = .medium
                            }
                        } else {
                            openPlanningSheet(focusing: defaultPlanningFocusWaypointID)
                        }
                    },
                    onFindRoute: {
                        await viewModel.findRoute()
                        await Task.yield()
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                            sheetPhase = .results
                            selectedDetent = .medium
                        }
                        refitMapToRoute()
                    },
                    onClose: {
                        dismissKeyboard()
                        isKeyboardVisible = false
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                            sheetPhase = .peek
                            selectedDetent = Self.peekDetent
                        }
                    },
                    onEditRoute: {
                        dismissKeyboard()
                        isKeyboardVisible = false
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                            sheetPhase = .planning
                            selectedDetent = .medium
                        }
                    }
                )
                .presentationDetents([Self.peekDetent, .medium, .large], selection: $selectedDetent)
                .presentationDragIndicator(.visible)
                .interactiveDismissDisabled()
                .modifier(RouteSheetBackgroundInteraction(isEnabled: !isKeyboardVisible && sheetPhase == .results))
            }
            .onChange(of: sheetPhase) { oldPhase, phase in
                isRouteSheetVisible = phase == .planning || phase == .results
                if phase != oldPhase, phase != .planning {
                    dismissKeyboard()
                    isKeyboardVisible = false
                } else if phase != oldPhase {
                    isKeyboardVisible = false
                }
                if phase == .planning, oldPhase != .planning { selectedDetent = .medium }
                if phase == .results, oldPhase != .results { selectedDetent = .medium }
                if phase == .peek, oldPhase != .peek { selectedDetent = Self.peekDetent }
                if phase == .peek, let modal = pendingModal {
                    pendingModal = nil
                    Task { @MainActor in
                        await Task.yield()
                        onPresentModal(modal)
                    }
                }
                refitMapToRoute()
            }
            .onChange(of: selectedDetent) { _, detent in
                if detent == Self.peekDetent, sheetPhase != .peek {
                    sheetPhase = .peek
                }
                refitMapToRoute()
            }
            .onAppear {
                isRouteSheetVisible = sheetPhase == .planning || sheetPhase == .results
                Task { @MainActor in
                    viewModel.seedUITestDemoRouteIfNeeded()
                    await Task.yield()
                    presentSeededResultsIfNeeded()
                }
            }
            .onChange(of: viewModel.uiTestForceResultsSheet) { _, force in
                if force { presentSeededResultsIfNeeded() }
            }
            .onChange(of: viewModel.result?.explanation) { _, _ in
                presentSeededResultsIfNeeded()
            }
    }

    private func presentSeededResultsIfNeeded() {
        guard viewModel.uiTestForceResultsSheet, viewModel.result != nil else { return }
        sheetPhase = .results
        let peekForUITest = UserDefaults.standard.bool(forKey: "RouteFinder.uitestPeekSheet")
        selectedDetent = peekForUITest ? Self.peekDetent : .medium
        isDetailExpanded = false
    }

    private func requestModal(_ modal: IOSModal) {
        dismissKeyboard()
        isKeyboardVisible = false
        // Hide the route sheet via MapFirstShell when a modal is presented; present immediately.
        onPresentModal(modal)
        if sheetPhase != .peek {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                sheetPhase = .peek
                selectedDetent = Self.peekDetent
            }
        }
    }

    private var toolbarBottomPadding: CGFloat {
        selectedDetent == Self.peekDetent ? 72 : 120
    }

    private func refitMapToRoute() {
        refitMapTask?.cancel()
        refitMapTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            guard viewModel.result != nil, !viewModel.routeCoordinates.isEmpty else { return }
            if sheetPhase == .results, selectedDetent == .large { return }
            viewModel.fitMapToRoute(padding: routeFitPadding)
        }
    }

    private var routeFitPadding: MapEdgePadding {
        switch sheetPhase {
        case .peek:
            MapEdgePadding(top: 72, bottom: 72, leading: 24, trailing: 24)
        case .planning, .results:
            MapEdgePadding(top: 72, bottom: 300, leading: 24, trailing: 24)
        }
    }

    private var isAtPeekDetent: Bool {
        selectedDetent == Self.peekDetent
    }

    private var topChrome: some View {
        VStack(spacing: RFSpacing.sm) {
            if !viewModel.hasCloudRoutingCapability, !isCloudBannerDismissed {
                compactCloudBanner
            }
            if let dispatchToast = viewModel.fleetDispatchToast {
                fleetDispatchToastBanner(dispatchToast)
            }
            if viewModel.result != nil, isAtPeekDetent {
                activeRouteChip
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var activeRouteChip: some View {
        Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                sheetPhase = .results
                selectedDetent = .medium
            }
        } label: {
            HStack(spacing: RFSpacing.sm) {
                Image(systemName: "arrow.triangle.turn.up.right.diamond.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(RFColor.route)
                Text(viewModel.destinationWaypoint.rawText.isEmpty ? "Route" : viewModel.destinationWaypoint.rawText)
                    .font(RFFont.summary)
                    .lineLimit(1)
                    .foregroundStyle(.primary)
                Spacer(minLength: 0)
                if let result = viewModel.result {
                    Text(formatRouteDuration(result.metrics.totalTime))
                        .font(RFFont.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                Image(systemName: "chevron.up")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, RFSpacing.md)
            .padding(.vertical, RFSpacing.sm + 2)
            .controlSheetStyle()
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("activeRouteChip")
    }

    private func formatRouteDuration(_ seconds: TimeInterval) -> String {
        let totalMinutes = Int(seconds / 60)
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }

    private var compactCloudBanner: some View {
        HStack(spacing: RFSpacing.sm) {
            Button {
                requestModal(.settings)
            } label: {
                HStack(spacing: RFSpacing.sm) {
                    Image(systemName: "cloud.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(viewModel.hasCloudRoutingCapability ? Color.secondary : Color.orange)
                    Text(compactCloudBannerText)
                        .font(RFFont.caption)
                        .lineLimit(1)
                        .foregroundStyle(.primary)
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)

            Button {
                withAnimation { isCloudBannerDismissed = true }
            } label: {
                Image(systemName: "xmark")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, RFSpacing.md)
        .padding(.vertical, RFSpacing.sm)
        .glassPanel(cornerRadius: 12)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("cloudRoutingBanner")
    }

    private var compactCloudBannerText: String {
        if !viewModel.hasCloudRoutingCapability {
            return "Add API key or Pair with fleet"
        }
        let full = viewModel.cloudRoutingBanner ?? "Cloud routing"
        if full.count > 42 {
            return String(full.prefix(39)) + "…"
        }
        return full
    }

    private func fleetDispatchToastBanner(_ message: String) -> some View {
        HStack(spacing: RFSpacing.sm) {
            Image(systemName: "truck.box.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.green)
            Text(message)
                .font(RFFont.caption.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(2)
        }
        .padding(.horizontal, RFSpacing.md)
        .padding(.vertical, RFSpacing.sm)
        .glassPanel(cornerRadius: 12)
    }

    private var routeSearchPill: some View {
        HStack(spacing: RFSpacing.sm) {
            Button {
                openPlanningSheet(focusing: defaultPlanningFocusWaypointID)
            } label: {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 2) {
                Button {
                    openPlanningSheet(focusing: viewModel.originWaypoint.id)
                } label: {
                    Text(viewModel.originWaypoint.rawText.isEmpty ? "Choose starting point" : viewModel.originWaypoint.rawText)
                        .font(RFFont.caption)
                        .lineLimit(1)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Button {
                    openPlanningSheet(focusing: viewModel.destinationWaypoint.id)
                } label: {
                    Text(viewModel.destinationWaypoint.rawText.isEmpty ? "Choose destination" : viewModel.destinationWaypoint.rawText)
                        .font(RFFont.summary)
                        .lineLimit(1)
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }

            Spacer(minLength: 0)

            Button {
                openPlanningSheet(focusing: defaultPlanningFocusWaypointID)
            } label: {
                Image(systemName: "chevron.up")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)

            if viewModel.result != nil {
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                        sheetPhase = .results
                        selectedDetent = .large
                    }
                } label: {
                    Image(systemName: "map.fill")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(RFColor.route)
                        .frame(width: 36, height: 36)
                        .background(.ultraThinMaterial, in: Circle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, RFSpacing.md)
        .padding(.vertical, RFSpacing.sm + 2)
        .controlSheetStyle()
    }

    private var defaultPlanningFocusWaypointID: UUID {
        if viewModel.originWaypoint.rawText.trimmingCharacters(in: .whitespaces).isEmpty {
            return viewModel.originWaypoint.id
        }
        if viewModel.destinationWaypoint.rawText.trimmingCharacters(in: .whitespaces).isEmpty {
            return viewModel.destinationWaypoint.id
        }
        return viewModel.destinationWaypoint.id
    }

    private func openPlanningSheet(focusing waypointID: UUID) {
        pendingFocusWaypointID = waypointID
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            sheetPhase = .planning
            selectedDetent = .medium
        }
    }
}

private struct RouteSheetBackgroundInteraction: ViewModifier {
    let isEnabled: Bool

    func body(content: Content) -> some View {
        if isEnabled {
            content.presentationBackgroundInteraction(.enabled(upThrough: .medium))
        } else {
            content
        }
    }
}

private enum IOSRouteSheetPhase {
    case peek
    case planning
    case results
}

private struct IOSRouteSheet: View {
    @Bindable var viewModel: RouteViewModel
    let phase: IOSRouteSheetPhase
    @Binding var isDetailExpanded: Bool
    @Binding var selectedDetent: PresentationDetent
    @Binding var isKeyboardVisible: Bool
    @Binding var pendingFocusWaypointID: UUID?
    @Binding var showAlertOverflow: Bool
    var onPeekTap: () -> Void
    var onFindRoute: () async -> Void
    var onClose: () -> Void
    var onEditRoute: () -> Void

    @FocusState private var focusedWaypointID: UUID?

    var body: some View {
        Group {
            if phase == .peek, selectedDetent == iosMapPeekDetent {
                peekContent
            } else {
                expandedSheetContent
            }
        }
        .sheet(isPresented: $showAlertOverflow) {
            MapAlertOverflowSheet(viewModel: viewModel)
        }
    }

    private var peekContent: some View {
        Button(action: onPeekTap) {
            HStack(spacing: RFSpacing.sm) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                Text(peekPromptText)
                    .font(RFFont.summary)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "mic.fill")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, RFSpacing.md)
            .padding(.vertical, RFSpacing.md)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("mapSearchPeekBar")
    }

    private var peekPromptText: String {
        if viewModel.result != nil,
           !viewModel.destinationWaypoint.rawText.isEmpty {
            return viewModel.destinationWaypoint.rawText
        }
        return "Where to?"
    }

    private var expandedSheetContent: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: RFSpacing.md) {
                    if phase == .planning {
                        planningContent
                    } else {
                        resultsContent
                    }
                }
                .padding(RFSpacing.md)
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(phase == .planning ? "Route Search" : "Route")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(phase == .planning ? "Close" : "Edit") {
                        dismissRouteSearchFocus($focusedWaypointID)
                        if phase == .planning {
                            onClose()
                        } else {
                            onEditRoute()
                        }
                    }
                }
                if phase == .planning {
                    ToolbarItem(placement: .confirmationAction) {
                        Button {
                            Task {
                                dismissRouteSearchFocus($focusedWaypointID)
                                await onFindRoute()
                            }
                        } label: {
                            if viewModel.isCalculating {
                                ProgressView().controlSize(.small)
                            } else {
                                Text("Find Route")
                            }
                        }
                        .disabled(!viewModel.canFindRoute || viewModel.isCalculating)
                    }
                }
            }
            .onChange(of: focusedWaypointID) { _, focusedID in
                isKeyboardVisible = focusedID != nil
            }
            .onChange(of: pendingFocusWaypointID) { _, waypointID in
                applyPendingFocus(waypointID)
            }
            .onChange(of: phase) { _, newPhase in
                if newPhase == .planning {
                    applyPendingFocus(pendingFocusWaypointID)
                }
            }
            .onChange(of: viewModel.pendingDisambiguation?.id) { _, _ in
                if viewModel.pendingDisambiguation != nil {
                    dismissRouteSearchFocus($focusedWaypointID)
                }
            }
        }
    }

    private func applyPendingFocus(_ waypointID: UUID?) {
        guard phase == .planning, let waypointID else { return }
        Task { @MainActor in
            await Task.yield()
            try? await Task.sleep(for: .milliseconds(150))
            focusedWaypointID = waypointID
            pendingFocusWaypointID = nil
        }
    }

    @ViewBuilder
    private var planningContent: some View {
        if let request = viewModel.pendingDisambiguation {
            GeocodeDisambiguationSheet(
                query: request.query,
                candidates: request.candidates,
                onSelect: { suggestion in
                    Task { await viewModel.resolveDisambiguation(suggestion) }
                },
                onCancel: { viewModel.cancelDisambiguation() }
            )
        } else {
            VStack(alignment: .leading, spacing: RFSpacing.sm) {
                RouteSearchFields(viewModel: viewModel, focusedWaypointID: $focusedWaypointID)

            if let optimizationError = viewModel.optimizationError {
                Label(optimizationError, systemImage: "exclamationmark.triangle.fill")
                    .font(RFFont.caption)
                    .foregroundStyle(.red)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if viewModel.routeFailure != nil {
                Text("Route failed — see details")
                    .font(RFFont.caption)
                    .foregroundStyle(.secondary)
            }

                HStack {
                    Button("Add Stop") { viewModel.addWaypoint() }
                        .buttonStyle(.borderless)
                    Button("Optimize Sequence") {
                        Task { await viewModel.optimizeWaypointSequence() }
                    }
                    .buttonStyle(.borderless)
                    .disabled(!viewModel.canOptimizeSequence || viewModel.isOptimizing || viewModel.isCalculating)
                }
            }
        }
    }

    @ViewBuilder
    private var resultsContent: some View {
        if let failure = viewModel.routeFailure {
            RouteFailureSheet(presentation: failure) {
                viewModel.routeFailure = nil
            }
        } else {
            if viewModel.isRouteDimensionBlocked {
                RouteBlockedOverlay()
            } else if viewModel.showsHGVRouteFailureBanner {
                HGVRouteFailureBanner()
            }

            if viewModel.result != nil {
                RouteProfileBadge(label: viewModel.routeProfileBadgeLabel)
                CompactAlertStack(viewModel: viewModel, showOverflow: $showAlertOverflow)
                Text("Waze routes as car with live traffic; RouteFinder uses OpenRouteService without traffic on first calculation.")
                    .font(RFFont.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                NavigationStartRow(
                    viewModel: viewModel,
                    onStarted: {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                            selectedDetent = .medium
                            isDetailExpanded = false
                        }
                    }
                )
            }

            RouteSummaryCard(
                viewModel: viewModel,
                embeddedInBottomSheet: true,
                isExpanded: (viewModel.errorMessage != nil && viewModel.result == nil)
                    ? .constant(false)
                    : $isDetailExpanded
            )
        }
    }
}

/// Shows at most two route alerts; overflow opens a sheet.
private struct CompactAlertStack: View {
    @Bindable var viewModel: RouteViewModel
    @Binding var showOverflow: Bool

    private var navigationActive: Bool {
        viewModel.isNavigationSessionActiveFromResults || viewModel.simulationEngine.isRunning
    }

    private var alerts: [MapAlertItem] {
        var items: [MapAlertItem] = []
        if let risk = viewModel.primaryRouteRiskAdvisory {
            items.append(.predictiveRisk(risk))
        } else {
            if let hazard = viewModel.activeHazardAheadAnnouncement {
                items.append(.hazard(hazard))
            }
            if let roadworks = viewModel.activeRoadworksAhead,
               let message = RoadworksAheadFormatter.bannerMessage(
                   site: roadworks,
                   currentArcLengthMeters: viewModel.currentRouteArcLengthForDisplay
               ) {
                items.append(.roadworks(message))
            }
            if let kinetic = viewModel.latestKineticAdvisory {
                items.append(.kinetic(kinetic.spokenText))
            }
        }
        if viewModel.trafficRerouteAvailable || viewModel.isEvaluatingTrafficReroute {
            items.append(.trafficReroute(viewModel.isEvaluatingTrafficReroute))
        }
        if let restriction = viewModel.activeRestrictionAnnouncement,
           !isLongHaulRoute(viewModel) {
            items.append(.restriction(restriction))
        }
        if let advisory = viewModel.laybyAdvisory {
            items.append(.layby(advisory))
        }
        if viewModel.hosEnabled, let hos = viewModel.hosSnapshot {
            items.append(.hos(hos))
        }
        if navigationActive,
           let lane = viewModel.activeLaneGuidance,
           let maneuver = viewModel.activeLaneManeuver,
           let distance = viewModel.activeLaneDistanceMeters {
            items.append(.lane(lane, maneuver, distance))
        }
        return items
    }

    private func isLongHaulRoute(_ viewModel: RouteViewModel) -> Bool {
        guard let origin = viewModel.originWaypoint.resolved?.snappedCoordinate,
              let destination = viewModel.destinationWaypoint.resolved?.snappedCoordinate else {
            return false
        }
        return mapAlertHaversineMeters(origin, destination) > LEZAvoidPolicy.avoidPolygonsMaxHaversineMeters
    }

    var body: some View {
        let visible = alerts.prefix(2)
        let overflowCount = max(0, alerts.count - 2)
        if !visible.isEmpty || overflowCount > 0 {
            VStack(spacing: RFSpacing.sm) {
                ForEach(Array(visible.enumerated()), id: \.offset) { _, item in
                    item.view(viewModel: viewModel)
                }
                if overflowCount > 0 {
                    Button {
                        showOverflow = true
                    } label: {
                        HStack(spacing: RFSpacing.sm) {
                            Image(systemName: "bell.badge")
                                .font(.caption.weight(.semibold))
                            Text("\(overflowCount) more alert\(overflowCount == 1 ? "" : "s")")
                                .font(RFFont.caption.weight(.semibold))
                            Spacer(minLength: 0)
                            Image(systemName: "chevron.right")
                                .font(.caption2.weight(.semibold))
                        }
                        .foregroundStyle(.primary)
                        .padding(.horizontal, RFSpacing.md)
                        .padding(.vertical, RFSpacing.sm)
                        .glassPanel(cornerRadius: 12)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("mapAlertOverflowChip")
                }
            }
        }
    }
}

private enum MapAlertItem {
    case predictiveRisk(RouteRiskAdvisory)
    case hazard(HazardAheadAnnouncement)
    case roadworks(String)
    case trafficReroute(Bool)
    case restriction(RestrictionZoneAnnouncement)
    case layby(LaybyAdvisory)
    case hos(HosClockSnapshot)
    case kinetic(String)
    case lane(LaneGuidance, TurnManeuver, Double)

    @ViewBuilder
    func view(viewModel: RouteViewModel) -> some View {
        switch self {
        case .predictiveRisk(let advisory):
            PredictiveRiskPrimaryBanner(advisory: advisory)
        case .hazard(let announcement):
            HazardAheadBanner(announcement: announcement)
        case .roadworks(let message):
            RoadworksAheadBanner(message: message)
        case .trafficReroute(let isEvaluating):
            TrafficRerouteBanner(isEvaluating: isEvaluating) {
                Task { await viewModel.applyTrafficReroute() }
            }
        case .restriction(let announcement):
            CompactRestrictionZoneBanner(announcement: announcement)
        case .layby(let advisory):
            LaybyAdvisoryBanner(
                advisory: advisory,
                onLaybyFull: { viewModel.markCurrentLaybyFull() },
                onLaybyHasSpaces: { viewModel.markCurrentLaybyHasSpaces() }
            )
        case .hos(let snapshot):
            HosClockBanner(snapshot: snapshot)
        case .kinetic(let text):
            LiveKineticAdvisoryBanner(text: text)
        case .lane(let guidance, let maneuver, let distance):
            LaneGuidanceBanner(guidance: guidance, maneuver: maneuver, distanceMeters: distance)
        }
    }
}

/// Full alert list when more than two banners are active.
private struct MapAlertOverflowSheet: View {
    @Bindable var viewModel: RouteViewModel
    @Environment(\.dismiss) private var dismiss

    private var navigationActive: Bool {
        viewModel.isNavigationSessionActiveFromResults || viewModel.simulationEngine.isRunning
    }

    private var alerts: [MapAlertItem] {
        var items: [MapAlertItem] = []
        if let risk = viewModel.primaryRouteRiskAdvisory {
            items.append(.predictiveRisk(risk))
        } else {
            if let hazard = viewModel.activeHazardAheadAnnouncement {
                items.append(.hazard(hazard))
            }
            if let roadworks = viewModel.activeRoadworksAhead,
               let message = RoadworksAheadFormatter.bannerMessage(
                   site: roadworks,
                   currentArcLengthMeters: viewModel.currentRouteArcLengthForDisplay
               ) {
                items.append(.roadworks(message))
            }
            if let kinetic = viewModel.latestKineticAdvisory {
                items.append(.kinetic(kinetic.spokenText))
            }
        }
        if viewModel.trafficRerouteAvailable || viewModel.isEvaluatingTrafficReroute {
            items.append(.trafficReroute(viewModel.isEvaluatingTrafficReroute))
        }
        if let restriction = viewModel.activeRestrictionAnnouncement {
            items.append(.restriction(restriction))
        }
        if let advisory = viewModel.laybyAdvisory {
            items.append(.layby(advisory))
        }
        if viewModel.hosEnabled, let hos = viewModel.hosSnapshot {
            items.append(.hos(hos))
        }
        if navigationActive,
           let lane = viewModel.activeLaneGuidance,
           let maneuver = viewModel.activeLaneManeuver,
           let distance = viewModel.activeLaneDistanceMeters {
            items.append(.lane(lane, maneuver, distance))
        }
        return items
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: RFSpacing.sm) {
                    ForEach(Array(alerts.enumerated()), id: \.offset) { _, item in
                        item.view(viewModel: viewModel)
                    }
                }
                .padding(RFSpacing.md)
            }
            .navigationTitle("Route alerts")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

/// One-line LEZ / restriction chip with detail on tap.
private struct CompactRestrictionZoneBanner: View {
    let announcement: RestrictionZoneAnnouncement
    @State private var showDetail = false

    private var compactMessage: String {
        if announcement.kind == .lez {
            return "Avoiding \(announcement.label) — set emission class"
        }
        return announcement.label
    }

    var body: some View {
        Button {
            showDetail = true
        } label: {
            HStack(spacing: RFSpacing.sm) {
                Image(systemName: announcement.kind == .lez ? "leaf.circle.fill" : "nosign")
                    .foregroundStyle(announcement.kind == .lez ? .green : RFColor.hazard)
                Text(compactMessage)
                    .font(RFFont.caption.weight(.semibold))
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, RFSpacing.md)
            .padding(.vertical, RFSpacing.sm)
            .controlSheetStyle()
        }
        .buttonStyle(.plain)
        .accessibilityLabel(compactMessage)
        .alert(announcement.label, isPresented: $showDetail) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(announcement.message)
        }
    }
}

/// Primary Start / Stop control for the iOS route results sheet.
private struct NavigationStartRow: View {
    @Bindable var viewModel: RouteViewModel
    @ObservedObject private var simulationEngine: RouteSimulationEngine
    var onStarted: () -> Void

    init(viewModel: RouteViewModel, onStarted: @escaping () -> Void) {
        self.viewModel = viewModel
        self._simulationEngine = ObservedObject(wrappedValue: viewModel.simulationEngine)
        self.onStarted = onStarted
    }

    private var canStart: Bool {
        viewModel.result != nil
            && !viewModel.isCalculating
            && !viewModel.isRouteDimensionBlocked
    }

    private var isActive: Bool {
        if viewModel.preferredTelemetryMode == .simulation {
            return simulationEngine.isRunning
        }
        return viewModel.isFollowModeEnabled || viewModel.isNavigationActive
    }

    private var primaryTitle: String {
        if isActive { return "Stop" }
        switch viewModel.preferredTelemetryMode {
        case .simulation: return "Start Simulation"
        case .hardwareGPS: return "Start Navigation"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: RFSpacing.xs) {
            Button {
                if isActive {
                    viewModel.stopNavigationFromResults()
                } else {
                    Task {
                        await viewModel.startNavigationFromResults()
                        onStarted()
                    }
                }
            } label: {
                Text(primaryTitle)
                    .font(RFFont.summary.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!canStart && !isActive)
            .accessibilityIdentifier("startNavigationButton")

            Text("Or use the compass control on the map")
                .font(RFFont.caption)
                .foregroundStyle(.secondary)
        }
    }
}

private struct RouteProfileBadge: View {
    let label: String

    var body: some View {
        HStack(spacing: RFSpacing.sm) {
            Image(systemName: "arrow.triangle.branch")
                .font(.caption.weight(.semibold))
                .foregroundStyle(RFColor.route)
            Text(label)
                .font(RFFont.caption.weight(.semibold))
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, RFSpacing.md)
        .padding(.vertical, RFSpacing.sm)
        .glassPanel(cornerRadius: 12)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("routeProfileBadge")
        .accessibilityLabel(label)
    }
}

private struct IOSMapToolbar: View {
    @Bindable var viewModel: RouteViewModel
    var onOpenSettings: () -> Void
    var onOpenProfile: () -> Void
    var onOpenWalkaround: () -> Void = {}

    var body: some View {
        VStack(spacing: RFSpacing.sm) {
            MapControlButton(icon: "location.fill") {
                viewModel.recenterMap()
            }

            MapControlButton(icon: "square.stack.3d.up") {
                Task {
                    await viewModel.fallbackToOnlineMapStyle()
                }
            }
            .accessibilityLabel("Map layers")

            MapControlButton(icon: "gearshape.fill") {
                onOpenSettings()
            }
            .accessibilityLabel("Settings")
            .accessibilityIdentifier("mapToolbarSettings")

            if viewModel.isHGVMode {
                MapControlButton(icon: "checklist") {
                    onOpenWalkaround()
                }
                .accessibilityLabel("Walkaround check")
                .accessibilityIdentifier("walkaroundToolbarEntry")
            }

            if viewModel.result != nil {
                MapControlButton(icon: "map") {
                    viewModel.resetMapToRouteOverview()
                }
                .accessibilityLabel("Route overview")
                .accessibilityIdentifier("mapRouteOverviewButton")
            }

            Menu {
                Button {
                    viewModel.mapBridge?.zoomBy(1)
                } label: {
                    Label("Zoom in", systemImage: "plus.magnifyingglass")
                }
                Button {
                    viewModel.mapBridge?.zoomBy(-1)
                } label: {
                    Label("Zoom out", systemImage: "minus.magnifyingglass")
                }
                Button {
                    handleNavigationControlTap()
                } label: {
                    Label("Compass", systemImage: navigationControlIcon)
                }
                Button {
                    onOpenSettings()
                } label: {
                    Label("Settings", systemImage: "gearshape.fill")
                }
                .accessibilityIdentifier("mapToolbarSettings")

                if viewModel.isHGVMode {
                    Button {
                        onOpenWalkaround()
                    } label: {
                        Label("Walkaround check", systemImage: "checklist")
                    }
                    .accessibilityIdentifier("walkaroundToolbarEntry")
                }

                Button {
                    viewModel.isHGVMode.toggle()
                    if viewModel.isHGVMode { viewModel.applyHGVPreset() }
                    viewModel.scheduleVehicleWorkspacePersist()
                    Task { await viewModel.recalculateIfReady() }
                } label: {
                    Label(
                        viewModel.isHGVMode ? "Disable HGV Mode" : "Enable HGV Mode",
                        systemImage: viewModel.isHGVMode ? "truck.box.fill" : "truck.box"
                    )
                }

                Button {
                    onOpenProfile()
                } label: {
                    Label("Vehicle Profile", systemImage: "person.crop.rectangle.stack")
                }

                if viewModel.breakNowQuickActionEnabled,
                   viewModel.isHGVMode,
                   viewModel.result != nil,
                   !viewModel.upcomingLaybys.isEmpty {
                    Button {
                        Task { await viewModel.findBreakNow() }
                    } label: {
                        Label("Break now", systemImage: "cup.and.saucer.fill")
                    }
                }

                if viewModel.isFollowModeEnabled {
                    Button {
                        viewModel.isFollowModeEnabled = false
                        viewModel.isNavigationActive = false
                        viewModel.stopNavigation()
                    } label: {
                        Label("Stop Follow Mode", systemImage: "location.slash")
                    }
                }
            } label: {
                Image(systemName: "ellipsis.circle.fill")
                    .font(.body.weight(.semibold))
                    .frame(width: 44, height: 44)
                    .background(.ultraThinMaterial, in: Circle())
                    .overlay(Circle().strokeBorder(.white.opacity(0.2), lineWidth: 0.5))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("mapToolbarMenu")
            .depthShadow()
        }
    }

    private var navigationControlIcon: String {
        if !viewModel.isFollowModeEnabled {
            return "location.north.line"
        }
        return MapCameraControls.icon(for: viewModel.mapBridge?.cameraMode ?? .lockNorth)
    }

    private func handleNavigationControlTap() {
        if !viewModel.isFollowModeEnabled {
            viewModel.isFollowModeEnabled = true
            viewModel.isNavigationActive = true
            Task { await viewModel.startLocationServicesIfNeeded() }
        } else {
            MapCameraControls.cycle(viewModel: viewModel)
        }
    }
}

@MainActor
enum MapCameraControls {
    static func icon(for mode: CameraTrackingMode) -> String {
        switch mode {
        case .freePan: "hand.draw"
        case .lockNorth: "location.north.line.fill"
        case .lockHeading: "location.fill.viewfinder"
        }
    }

    static func cycle(viewModel: RouteViewModel) {
        let current = viewModel.mapBridge?.cameraMode ?? .lockNorth
        let next: CameraTrackingMode = switch current {
        case .lockNorth: .lockHeading
        case .lockHeading: .freePan
        case .freePan: .lockNorth
        }
        viewModel.mapBridge?.setCameraMode(next)
        if next != .freePan,
           let coordinate = viewModel.simulationEngine.currentCoordinate
               ?? viewModel.navigationCoordinator.session.latestPosition?.coordinate {
            viewModel.mapBridge?.resumeTracking(at: coordinate, mode: next)
        }
    }
}

private func mapAlertHaversineMeters(_ a: Coordinate, _ b: Coordinate) -> Double {
    let earthRadius = 6_371_000.0
    let lat1 = a.latitude * .pi / 180
    let lat2 = b.latitude * .pi / 180
    let dLat = (b.latitude - a.latitude) * .pi / 180
    let dLon = (b.longitude - a.longitude) * .pi / 180
    let h = sin(dLat / 2) * sin(dLat / 2)
        + cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2)
    return 2 * earthRadius * asin(min(1, sqrt(h)))
}
#endif
