import Contracts
import CoreLocation
import RouteController
import SwiftUI

/// Collapsible route summary merging results, clearance report, turn-by-turn, and simulation.
struct RouteSummaryCard: View {
    @Bindable var viewModel: RouteViewModel
    @ObservedObject private var simulationEngine: RouteSimulationEngine
    var embeddedInBottomSheet = false
    @Binding var isExpanded: Bool

    init(viewModel: RouteViewModel, embeddedInBottomSheet: Bool = false, isExpanded: Binding<Bool> = .constant(false)) {
        self.viewModel = viewModel
        self._simulationEngine = ObservedObject(wrappedValue: viewModel.simulationEngine)
        self.embeddedInBottomSheet = embeddedInBottomSheet
        self._isExpanded = isExpanded
    }

    private var showsSimulationControls: Bool {
        viewModel.result != nil && viewModel.routeCoordinates.count >= 3
    }

    var body: some View {
        VStack(alignment: .leading, spacing: RFSpacing.sm) {
            if !embeddedInBottomSheet {
                HStack(spacing: 6) {
                    Image(systemName: "point.topleft.down.curvedto.point.bottomright.up")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(RFColor.route)
                    Text("Route Summary")
                        .font(RFFont.sectionTitle)
                    Spacer()
                }
            }

            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    isExpanded.toggle()
                }
            } label: {
                collapsedSummary
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                expandedContent
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .padding(embeddedInBottomSheet ? 0 : RFSpacing.md)
        .frame(maxWidth: embeddedInBottomSheet ? .infinity : 380)
        .frame(maxHeight: embeddedInBottomSheet ? nil : (isExpanded ? (showsSimulationControls ? 520 : 400) : nil))
        .modifier(ConditionalSheetStyle(embedded: embeddedInBottomSheet))
    }

    @ViewBuilder
    private var collapsedSummary: some View {
        HStack(alignment: .center, spacing: RFSpacing.sm) {
            if viewModel.isCalculating {
                ProgressView()
                    .controlSize(.small)
                Text("Calculating route…")
                    .font(RFFont.summary)
                    .foregroundStyle(.secondary)
            } else if viewModel.isEstimatingPhysicsDuration, viewModel.result == nil {
                ProgressView()
                    .controlSize(.small)
                Text("Estimating physics ETA…")
                    .font(RFFont.summary)
                    .foregroundStyle(.secondary)
            } else if let error = viewModel.errorMessage, viewModel.result == nil {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                Text(error)
                    .font(RFFont.caption)
                    .foregroundStyle(.red)
                    .lineLimit(2)
            } else if let result = viewModel.result {
                VStack(alignment: .leading, spacing: 2) {
                    Text(summaryLine(for: result))
                        .font(RFFont.summary)
                        .vibrancyLabel()
                        .lineLimit(1)
                    if viewModel.isEstimatingPhysicsDuration {
                        Text("Refining physics ETA…")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer(minLength: 4)

                if simulationEngine.currentCoordinate != nil || simulationEngine.isRunning {
                    speedDial(compact: true)
                }

                Image(systemName: isExpanded ? "chevron.down" : "chevron.up")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            } else {
                Text("Set a destination to calculate a route")
                    .font(RFFont.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }
        }
    }

    @ViewBuilder
    private var expandedContent: some View {
        if let result = viewModel.result {
            ScrollView {
                VStack(alignment: .leading, spacing: RFSpacing.sm) {
                    metricsSection(result: result)

                    VehicleClearanceReportView(
                        vehicle: viewModel.currentVehicleProfile(),
                        isHGVMode: viewModel.isHGVMode,
                        routeSucceeded: true,
                        isDimensionBlocked: viewModel.isRouteDimensionBlocked
                    )

                    Divider()

                    TurnByTurnList(
                        instructions: result.turnInstructions,
                        routeReferenceCoordinate: viewModel.routeCoordinates.first,
                        displayMeasurementSystem: viewModel.displayMeasurementSystem
                    )

                    if showsSimulationControls {
                        Divider()
                        if let lane = viewModel.activeLaneGuidance,
                           let maneuver = viewModel.activeLaneManeuver,
                           let distance = viewModel.activeLaneDistanceMeters {
                            LaneGuidanceBanner(
                                guidance: lane,
                                maneuver: maneuver,
                                distanceMeters: distance
                            )
                        }
                        SimulationControlRow(
                            viewModel: viewModel,
                            simulationEngine: simulationEngine,
                            isRunning: simulationEngine.isRunning
                        )
                    }

                    if !viewModel.upcomingTruckPois.isEmpty || viewModel.isLoadingTruckPois {
                        Divider()
                        TruckPoiAheadList(
                            pois: viewModel.upcomingTruckPois,
                            isLoading: viewModel.isLoadingTruckPois
                        )
                    }

                    if let report = simulationEngine.telemetryReport {
                        Divider()
                        PredictiveTelemetryReportView(
                            report: report,
                            briefContext: viewModel.tripBriefContext()
                        )
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func metricsSection(result: SearchResult) -> some View {
        if viewModel.hurryMode {
            Label("Hurry Mode Active", systemImage: "bolt.fill")
                .font(RFFont.caption)
                .foregroundStyle(RFColor.hazard)
        }

        if viewModel.isHGVMode {
            Label("HGV Mode Active", systemImage: "truck.box.fill")
                .font(RFFont.caption)
                .foregroundStyle(RFColor.hazard)
        }

        Text(result.explanation)
            .font(RFFont.caption)
            .vibrancyLabel()

        HStack {
            if viewModel.navigationMetrics.isLiveNavigationActive,
               let snapshot = viewModel.navigationMetrics.snapshot {
                Label(String(format: "%.1f km left", snapshot.remainingDistanceMeters / 1000), systemImage: "road.lanes")
                Label(formatTime(snapshot.remainingETASeconds) + " ETA", systemImage: "clock")
            } else {
                Label(String(format: "%.1f km", result.metrics.totalDistance / 1000), systemImage: "road.lanes")
                Label(formatTime(displayedRouteDuration(for: result)), systemImage: "clock")
            }
        }
        .font(RFFont.caption)
        .foregroundStyle(.secondary)

        if viewModel.physicsPredictedDurationSeconds != nil,
           !viewModel.navigationMetrics.isLiveNavigationActive {
            Text("Web routing: \(formatTime(result.metrics.totalTime))")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }

        HStack {
            Label(String(format: "%.0f ms", result.runtime * 1000), systemImage: "speedometer")
            Label("\(result.nodesVisited) nodes", systemImage: "point.3.connected.trianglepath.dotted")
        }
        .font(.caption2)
        .foregroundStyle(.secondary)

        if result.metrics.tollSegmentCount > 0 || result.metrics.ferrySegmentCount > 0 || result.metrics.tunnelSegmentCount > 0 {
            HStack(spacing: 12) {
                if result.metrics.tollSegmentCount > 0 {
                    Label("\(result.metrics.tollSegmentCount) toll(s)", systemImage: "dollarsign.circle")
                }
                if result.metrics.ferrySegmentCount > 0 {
                    Label("\(result.metrics.ferrySegmentCount) ferry(s)", systemImage: "ferry")
                }
                if result.metrics.tunnelSegmentCount > 0 {
                    Label("\(result.metrics.tunnelSegmentCount) tunnel(s)", systemImage: "tunnel")
                }
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
    }

    private func summaryLine(for result: SearchResult) -> String {
        if viewModel.navigationMetrics.isLiveNavigationActive,
           let snapshot = viewModel.navigationMetrics.snapshot {
            let distance = String(format: "%.1f km", snapshot.remainingDistanceMeters / 1000)
            let time = formatTime(snapshot.remainingETASeconds)
            return "\(distance) left • \(time) ETA"
        }
        let distance = String(format: "%.1f km", result.metrics.totalDistance / 1000)
        let time = formatTime(displayedRouteDuration(for: result))
        if result.metrics.speedCameraCount > 0 {
            return "\(distance) • \(time) • \(result.metrics.speedCameraCount) cameras"
        }
        return "\(distance) • \(time)"
    }

    private func displayedRouteDuration(for result: SearchResult) -> TimeInterval {
        viewModel.journeyPhysicsETASeconds
            ?? viewModel.physicsPredictedDurationSeconds
            ?? result.metrics.totalTime
    }

    private func formatTime(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds) / 60
        if minutes < 60 { return "\(minutes) min" }
        return "\(minutes / 60)h \(minutes % 60)m"
    }

    @ViewBuilder
    private func speedDial(compact: Bool) -> some View {
        let values = dialSpeedValues
        WazeSpeedDial(
            currentSpeed: values.current,
            speedLimit: values.limit,
            effectiveSpeedLimit: values.effectiveLimit,
            unitLabel: values.unit,
            compact: compact
        )
    }

    private var dialSpeedValues: (current: Double, limit: Double?, effectiveLimit: Double?, unit: String) {
        let currentKmh = simulationEngine.currentSpeedKmh
        let limitKmh = simulationEngine.activeLegalSpeedLimitKmh
        let effectiveKmh = simulationEngine.trafficAdjustedLimitKmh
        let system = viewModel.displayMeasurementSystem
        switch system {
        case .imperial:
            return (
                currentKmh * 0.621371,
                limitKmh.map { $0 * 0.621371 },
                effectiveKmh.map { $0 * 0.621371 },
                "mph"
            )
        case .metric:
            return (currentKmh, limitKmh, effectiveKmh, "km/h")
        }
    }
}

/// Playback controls for route simulation.
private struct SimulationControlRow: View {
    @Bindable var viewModel: RouteViewModel
    @ObservedObject var simulationEngine: RouteSimulationEngine
    let isRunning: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: RFSpacing.sm) {
            Text("Route Simulation")
                .font(RFFont.sectionTitle)

            HStack(spacing: RFSpacing.sm) {
                Button {
                    simulationEngine.toggleSimulation()
                } label: {
                    Image(systemName: isRunning ? "pause.fill" : "play.fill")
                        .font(.body.weight(.semibold))
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.plain)
                .controlSheetStyle()

                Picker("Speed", selection: Binding(
                    get: { simulationEngine.speedMultiplier },
                    set: { simulationEngine.simulationSpeedMultiplier = $0.rawValue }
                )) {
                    ForEach(SpeedMultiplier.allCases) { multiplier in
                        Text(multiplier.label).tag(multiplier)
                    }
                }
                .pickerStyle(.segmented)

                Spacer(minLength: 4)

                dialFromEngine
            }

            Button {
                viewModel.rehearseRoute()
            } label: {
                HStack(spacing: 6) {
                    if viewModel.isRehearsingRoute {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: "flame.fill")
                    }
                    Text(viewModel.isRehearsingRoute ? "Rehearsing…" : "Rehearse Route")
                        .font(RFFont.caption.weight(.semibold))
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.isRehearsingRoute || viewModel.isEstimatingPhysicsDuration || isRunning)

            if viewModel.tripBriefShareText != nil {
                TripBriefShareMenu(
                    context: viewModel.tripBriefContext(),
                    labelStyle: .fullWidth
                )
                .buttonStyle(.bordered)
            }

            if let advisory = viewModel.latestKineticAdvisory {
                KineticAdvisoryBanner(advisory: advisory)
            }

            HStack(spacing: RFSpacing.sm) {
                Image(systemName: "minus.magnifyingglass")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Slider(
                    value: Binding(
                        get: { viewModel.simulationCameraZoom },
                        set: { viewModel.setSimulationCameraZoom($0) }
                    ),
                    in: 12...19,
                    step: 0.25
                )
                Image(systemName: "plus.magnifyingglass")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(String(format: "%.1f", viewModel.simulationCameraZoom))
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(width: 28, alignment: .trailing)
            }

            Button {
                viewModel.presentHazardReportSheet = true
            } label: {
                Label("Report hazard", systemImage: "exclamationmark.bubble")
                    .font(RFFont.caption)
            }
            .buttonStyle(.borderless)
        }
        .padding(RFSpacing.sm)
        .controlSheetStyle()
    }

    private var dialFromEngine: some View {
        let currentKmh = simulationEngine.currentSpeedKmh
        let limitKmh = simulationEngine.activeLegalSpeedLimitKmh
        let effectiveKmh = simulationEngine.trafficAdjustedLimitKmh
        let system = viewModel.displayMeasurementSystem
        let current: Double
        let limit: Double?
        let effective: Double?
        let unit: String
        switch system {
        case .imperial:
            current = currentKmh * 0.621371
            limit = limitKmh.map { $0 * 0.621371 }
            effective = effectiveKmh.map { $0 * 0.621371 }
            unit = "mph"
        case .metric:
            current = currentKmh
            limit = limitKmh
            effective = effectiveKmh
            unit = "km/h"
        }
        return WazeSpeedDial(
            currentSpeed: current,
            speedLimit: limit,
            effectiveSpeedLimit: effective,
            unitLabel: unit,
            compact: false
        )
    }
}

private struct KineticAdvisoryBanner: View {
    let advisory: KineticAdvisory

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: iconName)
                .foregroundStyle(RFColor.hazard)
            Text(advisory.spokenText)
                .font(RFFont.caption.weight(.semibold))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(RFColor.hazard.opacity(0.4), lineWidth: 1)
        )
    }

    private var iconName: String {
        switch advisory.kind {
        case .brakeFade: "thermometer.high"
        case .steepGrade: "mountain.2.fill"
        case .tireSlip: "circle.dotted"
        case .hardDeceleration: "exclamationmark.triangle.fill"
        }
    }
}

private struct ConditionalSheetStyle: ViewModifier {
    let embedded: Bool

    func body(content: Content) -> some View {
        if embedded {
            content
        } else {
            content.controlSheetStyle()
        }
    }
}
