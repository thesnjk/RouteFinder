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
        HStack {
            if viewModel.isCalculating {
                ProgressView()
                    .controlSize(.small)
                Text("Calculating route…")
                    .font(RFFont.summary)
                    .foregroundStyle(.secondary)
            } else if let error = viewModel.errorMessage {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                Text(error)
                    .font(RFFont.caption)
                    .foregroundStyle(.red)
                    .lineLimit(2)
            } else if let result = viewModel.result {
                Text(summaryLine(for: result))
                    .font(RFFont.summary)
                    .vibrancyLabel()

                if result.metrics.speedCameraCount > 0 {
                    Label("\(result.metrics.speedCameraCount)", systemImage: "camera.fill")
                        .font(RFFont.caption)
                        .foregroundStyle(RFColor.hazard)
                }
            } else {
                Text("Set a destination to calculate a route")
                    .font(RFFont.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if viewModel.result != nil {
                Image(systemName: isExpanded ? "chevron.down" : "chevron.up")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
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
                        routeReferenceCoordinate: viewModel.routeCoordinates.first
                    )

                    if showsSimulationControls {
                        Divider()
                        SimulationControlRow(
                            simulationEngine: simulationEngine,
                            isRunning: simulationEngine.isRunning
                        )
                    }

                    if let report = simulationEngine.telemetryReport {
                        Divider()
                        PredictiveTelemetryReportView(report: report)
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
                Label(formatTime(result.metrics.totalTime), systemImage: "clock")
            }
        }
        .font(RFFont.caption)
        .foregroundStyle(.secondary)

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
        let time = formatTime(result.metrics.totalTime)
        if result.metrics.speedCameraCount > 0 {
            return "\(distance) • \(time) • \(result.metrics.speedCameraCount) cameras"
        }
        return "\(distance) • \(time)"
    }

    private func formatTime(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds) / 60
        if minutes < 60 { return "\(minutes) min" }
        return "\(minutes / 60)h \(minutes % 60)m"
    }
}

/// Playback controls for route simulation.
private struct SimulationControlRow: View {
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

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(formattedCurrentSpeed)
                        .font(RFFont.summary.monospacedDigit())
                    if let postedLimit = formattedPostedSpeedLimit {
                        Text(postedLimit)
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    if simulationEngine.isBrakingWarning {
                        Label("Braking", systemImage: "exclamationmark.triangle.fill")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                    }
                }
            }
        }
        .padding(RFSpacing.sm)
        .controlSheetStyle()
    }

    private var formattedPostedSpeedLimit: String? {
        guard let limitKmh = simulationEngine.activeLegalSpeedLimitKmh else { return nil }
        if let coordinate = simulationEngine.currentCoordinate {
            let formatted = TelemetryUnitConverter.formatSpeedKmh(limitKmh, at: coordinate)
            return "Limit \(formatted)"
        }
        return "Limit \(TelemetryUnitConverter.formatSpeedKmh(limitKmh, system: .metric))"
    }

    private var formattedCurrentSpeed: String {
        if let coordinate = simulationEngine.currentCoordinate {
            return TelemetryUnitConverter.formatSpeedKmh(simulationEngine.currentSpeedKmh, at: coordinate)
        }
        return TelemetryUnitConverter.formatSpeedKmh(
            simulationEngine.currentSpeedKmh,
            system: .metric
        )
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
