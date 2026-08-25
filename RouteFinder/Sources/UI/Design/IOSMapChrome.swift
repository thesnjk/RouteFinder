#if os(iOS)
import Contracts
import MapLibreUI
import RouteController
import SwiftUI

/// Maps-style iOS map chrome: compact top search, bottom detent sheet, consolidated toolbar.
struct IOSMapChrome: View {
    @Bindable var viewModel: RouteViewModel
    @Binding var isRouteSheetVisible: Bool
    var onPresentModal: (IOSModal) -> Void

    @AppStorage("dismissCloudRoutingBanner") private var isCloudBannerDismissed = false
    @State private var sheetPhase: IOSRouteSheetPhase = .hidden
    @State private var selectedDetent: PresentationDetent = .medium
    @State private var isDetailExpanded = false
    @State private var isKeyboardVisible = false
    @State private var pendingModal: IOSModal?
    @State private var pendingFocusWaypointID: UUID?

    var body: some View {
        Color.clear
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .allowsHitTesting(false)
            .overlay(alignment: .top) {
                topChrome
                    .padding(.horizontal, RFSpacing.md)
                    .safeAreaPadding(.top, RFSpacing.sm)
            }
            .overlay(alignment: .bottomTrailing) {
                IOSMapToolbar(
                    viewModel: viewModel,
                    onOpenSettings: { requestModal(.settings) },
                    onOpenProfile: { requestModal(.profile) }
                )
                .padding(.trailing, RFSpacing.md)
                .padding(.bottom, toolbarBottomPadding)
                .safeAreaPadding(.bottom)
            }
            .sheet(isPresented: routeSheetPresented) {
                IOSRouteSheet(
                    viewModel: viewModel,
                    phase: sheetPhase,
                    isDetailExpanded: $isDetailExpanded,
                    isKeyboardVisible: $isKeyboardVisible,
                    pendingFocusWaypointID: $pendingFocusWaypointID,
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
                        sheetPhase = .hidden
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
                .presentationDetents([.medium, .large], selection: $selectedDetent)
                .presentationDragIndicator(.visible)
                .modifier(RouteSheetBackgroundInteraction(isEnabled: !isKeyboardVisible && sheetPhase == .results))
            }
            .onChange(of: sheetPhase) { oldPhase, phase in
                isRouteSheetVisible = phase != .hidden
                if phase != oldPhase, phase != .planning {
                    dismissKeyboard()
                    isKeyboardVisible = false
                } else if phase != oldPhase {
                    isKeyboardVisible = false
                }
                if phase == .planning, oldPhase != .planning { selectedDetent = .medium }
                if phase == .results, oldPhase != .results { selectedDetent = .medium }
                if phase == .hidden, let modal = pendingModal {
                    pendingModal = nil
                    Task { @MainActor in
                        await Task.yield()
                        onPresentModal(modal)
                    }
                }
                refitMapToRoute()
            }
            .onChange(of: selectedDetent) { _, _ in
                refitMapToRoute()
            }
            .onAppear {
                isRouteSheetVisible = sheetPhase != .hidden
            }
    }

    private func requestModal(_ modal: IOSModal) {
        dismissKeyboard()
        isKeyboardVisible = false
        if sheetPhase != .hidden {
            pendingModal = modal
            sheetPhase = .hidden
        } else {
            onPresentModal(modal)
        }
    }

    private var toolbarBottomPadding: CGFloat {
        sheetPhase == .hidden ? RFSpacing.lg : 120
    }

    private func refitMapToRoute() {
        guard viewModel.result != nil, !viewModel.routeCoordinates.isEmpty else { return }
        if sheetPhase == .results, selectedDetent == .large { return }
        viewModel.fitMapToRoute(padding: routeFitPadding)
    }

    private var routeFitPadding: MapEdgePadding {
        switch sheetPhase {
        case .hidden:
            MapEdgePadding(top: 96, bottom: 120, leading: 24, trailing: 24)
        case .planning, .results:
            MapEdgePadding(top: 96, bottom: 300, leading: 24, trailing: 24)
        }
    }

    private var routeSheetPresented: Binding<Bool> {
        Binding(
            get: { sheetPhase != .hidden },
            set: { isPresented in
                if !isPresented {
                    dismissKeyboard()
                    isKeyboardVisible = false
                    sheetPhase = .hidden
                }
            }
        )
    }

    private var topChrome: some View {
        VStack(spacing: RFSpacing.sm) {
            if viewModel.cloudRoutingBanner != nil, !isCloudBannerDismissed {
                compactCloudBanner
            }
            if let advisory = viewModel.laybyAdvisory {
                LaybyAdvisoryBanner(advisory: advisory) {
                    viewModel.markCurrentLaybyFull()
                }
            }
<<<<<<< HEAD
            if viewModel.hosEnabled, let hos = viewModel.hosSnapshot {
                HosClockBanner(snapshot: hos)
            }
            if viewModel.trafficRerouteAvailable || viewModel.isEvaluatingTrafficReroute {
                TrafficRerouteBanner(isEvaluating: viewModel.isEvaluatingTrafficReroute) {
                    Task { await viewModel.applyTrafficReroute() }
                }
            }
=======
>>>>>>> 131ad0b45323f7aa6d871049cbbcf4238fd0ed3b
            if let restriction = viewModel.activeRestrictionAnnouncement {
                RestrictionZoneBanner(announcement: restriction)
            }
            if let kinetic = viewModel.latestKineticAdvisory {
                LiveKineticAdvisoryBanner(text: kinetic.spokenText)
            }
            routeSearchPill
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var compactCloudBanner: some View {
        HStack(spacing: RFSpacing.sm) {
            Button {
                requestModal(.settings)
            } label: {
                HStack(spacing: RFSpacing.sm) {
                    Image(systemName: "cloud.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text("Cloud routing — add API key")
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
    case hidden
    case planning
    case results
}

private struct IOSRouteSheet: View {
    @Bindable var viewModel: RouteViewModel
    let phase: IOSRouteSheetPhase
    @Binding var isDetailExpanded: Bool
    @Binding var isKeyboardVisible: Bool
    @Binding var pendingFocusWaypointID: UUID?
    var onFindRoute: () async -> Void
    var onClose: () -> Void
    var onEditRoute: () -> Void

    @FocusState private var focusedWaypointID: UUID?

    var body: some View {
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
        }

        if viewModel.isRouteDimensionBlocked {
            RouteBlockedOverlay()
        } else if viewModel.showsHGVRouteFailureBanner {
            HGVRouteFailureBanner()
        }

        RouteSummaryCard(
            viewModel: viewModel,
            embeddedInBottomSheet: true,
            isExpanded: $isDetailExpanded
        )
    }
}

private struct IOSMapToolbar: View {
    @Bindable var viewModel: RouteViewModel
    var onOpenSettings: () -> Void
    var onOpenProfile: () -> Void

    var body: some View {
        VStack(spacing: RFSpacing.sm) {
            MapControlButton(icon: "plus") {
                viewModel.mapBridge?.zoomBy(1)
            }

            MapControlButton(icon: "minus") {
                viewModel.mapBridge?.zoomBy(-1)
            }

            MapControlButton(icon: "location.fill") {
                viewModel.recenterMap()
            }

            MapControlButton(icon: navigationControlIcon) {
                handleNavigationControlTap()
            }

            if viewModel.simulationEngine.isRunning {
                MapControlButton(
                    icon: viewModel.mapBridge?.isTrackingVehicle == true
                        ? "location.north.line.fill"
                        : "location.north.line"
                ) {
                    if let coordinate = viewModel.simulationEngine.currentCoordinate {
                        viewModel.mapBridge?.resumeTracking(at: coordinate)
                    }
                }
            }

            Menu {
                Button {
                    onOpenSettings()
                } label: {
                    Label("Settings", systemImage: "gearshape.fill")
                }

                Button {
                    viewModel.isHGVMode.toggle()
                    if viewModel.isHGVMode { viewModel.applyHGVPreset() }
                    Task { await viewModel.recalculateIfReady() }
                } label: {
                    Label(
                        viewModel.isHGVMode ? "Disable HGV Mode" : "Enable HGV Mode",
                        systemImage: viewModel.isHGVMode ? "truck.box.fill" : "truck.box"
                    )
                }

                Button {
                    viewModel.avoidCameras.toggle()
                    Task { await viewModel.recalculateIfReady() }
                } label: {
                    Label(
                        viewModel.avoidCameras ? "Allow Speed Cameras" : "Avoid Speed Cameras",
                        systemImage: viewModel.avoidCameras ? "camera.fill" : "camera"
                    )
                }

                Button {
                    onOpenProfile()
                } label: {
                    Label("Vehicle Profile", systemImage: "person.crop.rectangle.stack")
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
#endif
