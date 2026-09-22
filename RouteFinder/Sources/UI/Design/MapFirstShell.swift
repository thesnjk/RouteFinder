import Contracts
import MapLibreUI
import RouteController
import SwiftUI

#if os(iOS)
import UIKit
#endif

/// Map-first shell: top route chips, floating controls, bottom route sheet.
struct MapFirstShell: View {
    @Bindable var viewModel: RouteViewModel
    var onOpenProfile: () -> Void = {}
    var onOpenSettings: () -> Void = {}
    var hideRouteSheet: Bool = false

    #if os(iOS)
    @State private var presentedModal: IOSModal?
    @State private var isRouteSheetVisible = false
    #endif

    var body: some View {
        #if os(iOS)
        IOSMapChrome(
            viewModel: viewModel,
            isRouteSheetVisible: $isRouteSheetVisible,
            hideRouteSheet: hideRouteSheet || presentedModal != nil,
            onPresentModal: { presentedModal = $0 },
            onOpenWalkaround: {
                viewModel.startWalkaroundInspection()
                presentedModal = .walkaround
            }
        )
        .overlay {
            if let presentedModal {
                iosModalContent(presentedModal)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(MapCanvasBackdrop.color)
                    .ignoresSafeArea()
                    .zIndex(20)
            }
        }
        .onAppear {
            #if DEBUG
            if UserDefaults.standard.bool(forKey: "RouteFinder.uitestOpenSettings") {
                UserDefaults.standard.set(false, forKey: "RouteFinder.uitestOpenSettings")
                presentedModal = .settings
            } else if UserDefaults.standard.bool(forKey: "RouteFinder.uitestOpenWalkaround") {
                UserDefaults.standard.set(false, forKey: "RouteFinder.uitestOpenWalkaround")
                viewModel.startWalkaroundInspection()
                presentedModal = .walkaround
            }
            #endif
        }
        .onChange(of: viewModel.routeFailure) { _, failure in
            guard let failure else { return }
            guard !isRouteSheetVisible else { return }
            presentedModal = .routeFailure(failure)
        }
        .sheet(isPresented: $viewModel.presentHazardReportSheet) {
            HazardReportSheet(viewModel: viewModel)
        }
        .alert(
            viewModel.pendingStillTherePrompt?.message ?? "Still there?",
            isPresented: Binding(
                get: { viewModel.pendingStillTherePrompt != nil },
                set: { if !$0 { viewModel.pendingStillTherePrompt = nil } }
            )
        ) {
            Button("Still there") { viewModel.resolveStillTherePrompt(stillPresent: true) }
            Button("Cleared", role: .cancel) { viewModel.resolveStillTherePrompt(stillPresent: false) }
        }
        #else
        macOSMapChrome
        #endif
    }

    #if os(iOS)
    @ViewBuilder
    private func iosModalContent(_ modal: IOSModal) -> some View {
        switch modal {
        case .settings:
            SettingsSheet(viewModel: viewModel, onDismiss: { presentedModal = nil })
        case .profile:
            NavigationStack {
                VehicleProfileManager(viewModel: viewModel)
            }
            .presentationDetents([.medium, .large])
        case .walkaround:
            InspectionWalkaroundSheet(viewModel: viewModel, onFinished: { presentedModal = nil })
        case .routeFailure(let failure):
            RouteFailureSheet(presentation: failure) {
                viewModel.routeFailure = nil
                presentedModal = nil
            }
        }
    }
    #endif

    #if os(macOS)
    @State private var isSearchExpanded = false
    @State private var isDetailExpanded = false
    @State private var isTelemetryPresented = false
    @FocusState private var focusedSearchWaypointID: UUID?

    private var macOSMapChrome: some View {
        ZStack(alignment: .topLeading) {
            topBar
                .frame(maxWidth: 420, alignment: .topLeading)
                .padding(.leading, RFSpacing.md)
                .padding(.top, RFSpacing.md)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .zIndex(20)

            floatingControls
                .padding(.trailing, RFSpacing.md)
                .padding(.top, 88)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .zIndex(15)
        }
        .overlay(alignment: .bottom) {
            bottomSheet
                .zIndex(10)
        }
        .sheet(isPresented: $isTelemetryPresented) {
            if let report = viewModel.simulationEngine.telemetryReport {
                ScrollView {
                    PredictiveTelemetryReportView(
                        report: report,
                        briefContext: viewModel.tripBriefContext()
                    )
                        .padding(RFSpacing.lg)
                }
                .frame(minWidth: 480, minHeight: 420)
            }
        }
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
        .onChange(of: viewModel.routeDetailCollapseTick) { _, _ in
            isDetailExpanded = false
        }
        .sheet(isPresented: $viewModel.presentHazardReportSheet) {
            HazardReportSheet(viewModel: viewModel)
        }
        .alert(
            viewModel.pendingStillTherePrompt?.message ?? "Still there?",
            isPresented: Binding(
                get: { viewModel.pendingStillTherePrompt != nil },
                set: { if !$0 { viewModel.pendingStillTherePrompt = nil } }
            )
        ) {
            Button("Still there") { viewModel.resolveStillTherePrompt(stillPresent: true) }
            Button("Cleared", role: .cancel) { viewModel.resolveStillTherePrompt(stillPresent: false) }
        }
    }
    #endif

    #if os(macOS)
    private var topBar: some View {
        VStack(spacing: RFSpacing.sm) {
            if let banner = viewModel.cloudRoutingBanner {
                cloudRoutingBannerView(banner)
            }

            if let dispatchToast = viewModel.fleetDispatchToast {
                fleetDispatchToastView(dispatchToast)
            }

            if let advisory = viewModel.activeTollAdvisory {
                TollAdvisoryBanner(
                    advisory: advisory,
                    distanceMeters: viewModel.activeTollAdvisoryDistanceMeters
                )
            }

            if let advisory = viewModel.laybyAdvisory {
                LaybyAdvisoryBanner(
                    advisory: advisory,
                    onLaybyFull: { viewModel.markCurrentLaybyFull() },
                    onLaybyHasSpaces: { viewModel.markCurrentLaybyHasSpaces() }
                )
            }

            if viewModel.hosEnabled, let hos = viewModel.hosSnapshot {
                HosClockBanner(snapshot: hos)
            }

            if viewModel.trafficRerouteAvailable || viewModel.isEvaluatingTrafficReroute {
                TrafficRerouteBanner(isEvaluating: viewModel.isEvaluatingTrafficReroute) {
                    Task { await viewModel.applyTrafficReroute() }
                }
            }

            if let hazard = viewModel.activeHazardAheadAnnouncement {
                HazardAheadBanner(announcement: hazard)
            }
            if let roadworks = viewModel.activeRoadworksAhead,
               let message = RoadworksAheadFormatter.bannerMessage(
                   site: roadworks,
                   currentArcLengthMeters: viewModel.currentRouteArcLengthForDisplay
               ) {
                RoadworksAheadBanner(message: message)
            }

            if let restriction = viewModel.activeRestrictionAnnouncement {
                RestrictionZoneBanner(announcement: restriction)
            }

            if let kinetic = viewModel.latestKineticAdvisory {
                LiveKineticAdvisoryBanner(text: kinetic.spokenText)
            }

            if let lane = viewModel.activeLaneGuidance,
               let maneuver = viewModel.activeLaneManeuver,
               let distance = viewModel.activeLaneDistanceMeters {
                LaneGuidanceBanner(guidance: lane, maneuver: maneuver, distanceMeters: distance)
            }

            if isSearchExpanded {
                expandedSearchPanel
                    .transition(.move(edge: .top).combined(with: .opacity))
            } else {
                collapsedRouteChips
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: isSearchExpanded)
    }

    private func cloudRoutingBannerView(_ message: String) -> some View {
        HStack(alignment: .top, spacing: RFSpacing.sm) {
            Image(systemName: "cloud.fill")
                .font(.body.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(message)
                .font(RFFont.caption)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, RFSpacing.md)
        .padding(.vertical, RFSpacing.sm)
        .frame(maxWidth: 420, alignment: .leading)
        .controlSheetStyle()
    }

    private func fleetDispatchToastView(_ message: String) -> some View {
        HStack(spacing: RFSpacing.sm) {
            Image(systemName: "truck.box.fill")
                .font(.body.weight(.semibold))
                .foregroundStyle(.green)
            Text(message)
                .font(RFFont.caption.weight(.semibold))
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, RFSpacing.md)
        .padding(.vertical, RFSpacing.sm)
        .frame(maxWidth: 420, alignment: .leading)
        .controlSheetStyle()
    }

    private var collapsedRouteChips: some View {
        Button {
            withAnimation { isSearchExpanded = true }
        } label: {
            HStack(spacing: RFSpacing.sm) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 2) {
                    Text(viewModel.originWaypoint.rawText.isEmpty ? "Choose starting point" : viewModel.originWaypoint.rawText)
                        .font(RFFont.caption)
                        .lineLimit(1)
                    Text(viewModel.destinationWaypoint.rawText.isEmpty ? "Choose destination" : viewModel.destinationWaypoint.rawText)
                        .font(RFFont.summary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.down")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, RFSpacing.md)
            .padding(.vertical, RFSpacing.sm + 2)
            .controlSheetStyle()
        }
        .buttonStyle(.plain)
    }

    private var expandedSearchPanel: some View {
        VStack(alignment: .leading, spacing: RFSpacing.sm) {
            HStack {
                Text("Route Search")
                    .font(RFFont.sectionTitle)
                Spacer()
                Button("Done") {
                    dismissRouteSearchFocus($focusedSearchWaypointID)
                    withAnimation { isSearchExpanded = false }
                }
                .buttonStyle(.borderless)
            }

            RouteSearchFields(viewModel: viewModel, focusedWaypointID: $focusedSearchWaypointID)

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
                Spacer()
                Button {
                    Task {
                        await viewModel.findRoute()
                        dismissRouteSearchFocus($focusedSearchWaypointID)
                        withAnimation { isSearchExpanded = false }
                    }
                } label: {
                    if viewModel.isCalculating {
                        ProgressView().controlSize(.small)
                    } else {
                        Text("Find Route")
                    }
                }
                .modifier(GlassButton())
                .disabled(!viewModel.canFindRoute || viewModel.isCalculating)
            }
        }
        .padding(RFSpacing.md + 4)
        .controlSheetStyle()
    }

    private var floatingControls: some View {
        VStack(spacing: RFSpacing.sm) {
            MapControlButton(icon: "gearshape.fill") {
                onOpenSettings()
            }

            MapControlButton(icon: viewModel.isHGVMode ? "truck.box.fill" : "truck.box") {
                viewModel.isHGVMode.toggle()
                if viewModel.isHGVMode { viewModel.applyHGVPreset() }
                viewModel.scheduleVehicleWorkspacePersist()
                Task { await viewModel.recalculateIfReady() }
            }

            MapControlButton(icon: viewModel.avoidCameras ? "camera.fill" : "camera") {
                viewModel.avoidCameras.toggle()
                Task { await viewModel.recalculateIfReady() }
            }

            MapControlButton(icon: "chart.bar.doc.horizontal.fill") {
                isTelemetryPresented = true
            }
            .disabled(viewModel.simulationEngine.telemetryReport == nil)

            MapControlButton(icon: "location.fill") {
                viewModel.recenterMap()
            }

            if viewModel.breakNowQuickActionEnabled,
               viewModel.isHGVMode,
               viewModel.result != nil,
               !viewModel.upcomingLaybys.isEmpty {
                MapControlButton(icon: "cup.and.saucer.fill") {
                    Task { await viewModel.findBreakNow() }
                }
                .accessibilityLabel("Break now")
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
        }
    }

    private var bottomSheet: some View {
        GeometryReader { geo in
            VStack {
                Spacer(minLength: 0)
                RouteBottomSheet(
                    viewModel: viewModel,
                    isDetailExpanded: $isDetailExpanded,
                    maxAvailableHeight: max(180, geo.size.height - RFSpacing.md * 2)
                )
                .padding(.horizontal, RFSpacing.md)
                .padding(.bottom, RFSpacing.md)
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .bottom)
        }
        .allowsHitTesting(true)
    }
    #endif
}

struct MapControlButton: View {
    let icon: String
    var action: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.body.weight(.semibold))
                .frame(width: 44, height: 44)
                .background(.ultraThinMaterial, in: Circle())
                .overlay(Circle().strokeBorder(.white.opacity(0.2), lineWidth: 0.5))
        }
        .buttonStyle(.plain)
        .depthShadow()
    }
}

/// Shared route search fields used by map-first shell and legacy sidebar.
struct RouteSearchFields: View {
    @Bindable var viewModel: RouteViewModel
    var focusedWaypointID: FocusState<UUID?>.Binding

    var body: some View {
        VStack(alignment: .leading, spacing: RFSpacing.sm) {
            // While the failure modal is up, avoid duplicating the long error here.
            if viewModel.routeFailure == nil, let error = viewModel.errorMessage {
                if viewModel.isRouteDimensionBlocked {
                    RouteBlockedOverlay()
                } else if viewModel.showsHGVRouteFailureBanner {
                    HGVRouteFailureBanner()
                } else {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .font(RFFont.caption)
                        .foregroundStyle(.red)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            ForEach($viewModel.routeWaypoints) { $waypoint in
                HStack {
                    LocationSearchField(
                        placeholder: placeholder(for: waypoint.role, waypoint: waypoint),
                        text: $waypoint.rawText,
                        focusTag: waypoint.id,
                        focusedWaypointID: focusedWaypointID,
                        isActive: viewModel.activePinTarget == .waypoint(waypoint.id),
                        resolutionStatus: viewModel.resolutionStatus(for: waypoint.id),
                        snapHint: snapHint(for: waypoint),
                        feedback: viewModel.searchFeedback(for: waypoint.id),
                        suggestions: viewModel.suggestions(for: waypoint.id),
                        onQueryChange: { viewModel.updateSearchSuggestions(for: waypoint.id, query: $0) },
                        onPinTap: { viewModel.beginPinMode(for: waypoint.id) },
                        onSelect: { suggestion in
                            Task { await viewModel.applySuggestion(suggestion, for: waypoint.id) }
                        }
                    )
                    .id(waypoint.id)

                    if waypoint.role == .via {
                        Button {
                            viewModel.removeWaypoint(id: waypoint.id)
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func placeholder(for role: RouteWaypoint.Role, waypoint: RouteWaypoint) -> String {
        switch role {
        case .origin: return "Choose starting point"
        case .destination: return "Choose destination"
        case .via:
            let viaIndex = viewModel.viaWaypoints.firstIndex(where: { $0.id == waypoint.id }).map { $0 + 1 } ?? 1
            return "Stop \(viaIndex)"
        }
    }

    private func snapHint(for waypoint: RouteWaypoint) -> String? {
        switch waypoint.role {
        case .origin, .destination:
            viewModel.snapHint(for: waypoint.id)
        case .via:
            nil
        }
    }
}

/// Bottom sheet route summary with turn-by-turn.
struct RouteBottomSheet: View {
    @Bindable var viewModel: RouteViewModel
    @Binding var isDetailExpanded: Bool
    /// Hard cap so the sheet cannot extend past the map column / window bottom.
    var maxAvailableHeight: CGFloat = 560
    @State private var dragOffset: CGFloat = 0

    private var isErrorOnly: Bool {
        viewModel.errorMessage != nil && viewModel.result == nil && !viewModel.isCalculating
    }

    private var shouldShow: Bool {
        // Prefer the modal for failures; keep a compact residual only after dismiss.
        if viewModel.routeFailure != nil { return false }
        return viewModel.originWaypoint.resolved != nil
            || viewModel.result != nil
            || viewModel.isCalculating
            || viewModel.errorMessage != nil
    }

    private var showsSimulationControls: Bool {
        viewModel.result != nil && viewModel.routeCoordinates.count >= 3
    }

    private var sheetExpandedHeight: CGFloat {
        let preferred: CGFloat = showsSimulationControls ? 520 : 400
        return min(preferred, maxAvailableHeight)
    }

    private var collapsedMaxHeight: CGFloat {
        if isErrorOnly {
            return min(120, maxAvailableHeight)
        }
        return min(200, maxAvailableHeight)
    }

    private var activeMaxHeight: CGFloat {
        if isErrorOnly {
            return collapsedMaxHeight
        }
        return isDetailExpanded ? sheetExpandedHeight : collapsedMaxHeight
    }

    var body: some View {
        if shouldShow {
            VStack(alignment: .leading, spacing: RFSpacing.sm) {
                HStack {
                    Capsule()
                        .fill(.secondary.opacity(0.35))
                        .frame(width: 36, height: 4)
                        .frame(maxWidth: .infinity)
                }
                .padding(.top, 4)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 20)
                        .onChanged { value in
                            dragOffset = value.translation.height
                        }
                        .onEnded { value in
                            guard !isErrorOnly else {
                                dragOffset = 0
                                return
                            }
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                if value.translation.height < -20 {
                                    isDetailExpanded = true
                                } else if value.translation.height > 20 {
                                    isDetailExpanded = false
                                }
                            }
                            dragOffset = 0
                        }
                )

                if viewModel.isRouteDimensionBlocked {
                    RouteBlockedOverlay()
                } else if viewModel.showsHGVRouteFailureBanner {
                    HGVRouteFailureBanner()
                }

                RouteSummaryCard(
                    viewModel: viewModel,
                    embeddedInBottomSheet: true,
                    isExpanded: isErrorOnly ? .constant(false) : $isDetailExpanded
                )
            }
            .padding(.top, RFSpacing.sm)
            .padding(.horizontal, RFSpacing.md)
            .padding(.bottom, RFSpacing.md)
            .frame(maxWidth: 560)
            .frame(maxHeight: activeMaxHeight, alignment: .top)
            .clipped()
            .controlSheetStyle()
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .allowsHitTesting(true)
            .frame(maxWidth: .infinity)
            .offset(y: dragOffset > 0 ? min(dragOffset, 40) : 0)
            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: isDetailExpanded)
            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: isErrorOnly)
        }
    }
}

/// Prominent banner when vehicle dimensions block the selected corridor.
struct RouteBlockedOverlay: View {
    var body: some View {
        HStack(alignment: .top, spacing: RFSpacing.sm) {
            Image(systemName: "exclamationmark.octagon.fill")
                .font(.title3.weight(.semibold))
                .foregroundStyle(RFColor.hazard)
            VStack(alignment: .leading, spacing: 4) {
                Text("Route Blocked")
                    .font(RFFont.sectionTitle)
                    .foregroundStyle(RFColor.hazard)
                Text(ExternalRoutingError.vehicleDimensionBlockedMessage)
                    .font(RFFont.caption)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(RFSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RFColor.hazard.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(RFColor.hazard.opacity(0.35), lineWidth: 1)
        )
    }
}

/// Prominent banner when no legal HGV route exists for the current vehicle profile.
struct HGVRouteFailureBanner: View {
    var body: some View {
        HStack(alignment: .top, spacing: RFSpacing.sm) {
            Image(systemName: "truck.box.fill")
                .font(.title3.weight(.semibold))
                .foregroundStyle(RFColor.hazard)
            VStack(alignment: .leading, spacing: 4) {
                Text("No HGV Route Available")
                    .font(RFFont.sectionTitle)
                    .foregroundStyle(RFColor.hazard)
                Text(ExternalRoutingError.hgvNoRouteMessage)
                    .font(RFFont.caption)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(RFSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RFColor.hazard.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(RFColor.hazard.opacity(0.35), lineWidth: 1)
        )
    }
}

#if os(iOS)
/// Secondary modals presented from the map shell (settings, profile, route failure).
enum IOSModal: Identifiable {
    case settings
    case profile
    case walkaround
    case routeFailure(RouteFailurePresentation)

    var id: String {
        switch self {
        case .settings: "settings"
        case .profile: "profile"
        case .walkaround: "walkaround"
        case .routeFailure(let presentation): "routeFailure-\(presentation.id)"
        }
    }
}
#endif
