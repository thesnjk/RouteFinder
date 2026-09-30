import Contracts
import CoreLocation
import SwiftUI
import UniformTypeIdentifiers

/// Dispatch detail: fleet roster, trip status, physics ETA, telemetry, predicted layby.
struct DispatchStatusPanel: View {
    let trip: FleetTrip?
    let vehicleLabel: String?
    let previewCoordinates: [CLLocationCoordinate2D]
    var telematicsImportBatch: TelematicsImportBatch? = nil
    var rosterRows: [DispatchRosterRow] = []
    var selectedVehicleId: UUID?
    /// When true, sidebar draft stops do not match this active trip.
    var draftDiffersFromActiveTrip: Bool = false
    var onSelectVehicle: ((UUID) -> Void)?

    init(
        trip: FleetTrip?,
        vehicleLabel: String? = nil,
        previewCoordinates: [CLLocationCoordinate2D] = [],
        telematicsImportBatch: TelematicsImportBatch? = nil,
        rosterRows: [DispatchRosterRow] = [],
        selectedVehicleId: UUID? = nil,
        draftDiffersFromActiveTrip: Bool = false,
        onSelectVehicle: ((UUID) -> Void)? = nil
    ) {
        self.trip = trip
        self.vehicleLabel = vehicleLabel
        self.previewCoordinates = previewCoordinates
        self.telematicsImportBatch = telematicsImportBatch
        self.rosterRows = rosterRows
        self.selectedVehicleId = selectedVehicleId
        self.draftDiffersFromActiveTrip = draftDiffersFromActiveTrip
        self.onSelectVehicle = onSelectVehicle
    }

    private func tripBriefContext(for trip: FleetTrip) -> TripBriefContext {
        let preview = previewCoordinates.map {
            Coordinate(latitude: $0.latitude, longitude: $0.longitude)
        }
        return TripBriefContext.from(
            fleetTrip: trip,
            vehicleLabel: vehicleLabel,
            previewCoordinates: preview
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: RFSpacing.md) {
                if let batch = telematicsImportBatch {
                    telematicsImportCard(batch)
                }
                fleetRosterSection
                if let trip {
                    if draftDiffersFromActiveTrip {
                        draftDiffersBanner
                    }
                    statusHeader(trip)
                    stopList(trip)
                    if let seconds = trip.physicsETASeconds {
                        etaRow(seconds: seconds)
                    }
                    if trip.driverLatitude != nil, trip.driverLongitude != nil {
                        lastPositionRow(trip)
                    } else {
                        waitingForGpsRow
                    }
                    if let report = trip.predictiveReport {
                        PredictiveTelemetryReportView(
                            report: report,
                            briefContext: tripBriefContext(for: trip)
                        )
                    }
                    if let layby = trip.predictedLayby {
                        laybyCard(layby)
                    }
                    if let inspection = trip.latestInspectionSummary, inspection.defectCount > 0 {
                        inspectionWarningCard(inspection, pdfBase64: trip.inspectionReportPDFBase64)
                    }
                } else {
                    Text("No active trip for the selected vehicle.")
                        .font(RFFont.caption)
                        .foregroundStyle(.secondary)
                        .controlSheetStyle()
                }
            }
            .padding(RFSpacing.lg)
        }
    }

    private var draftDiffersBanner: some View {
        Text("Draft differs from dispatched trip — Push to update driver")
            .font(RFFont.caption.weight(.semibold))
            .foregroundStyle(.orange)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, RFSpacing.md)
            .padding(.vertical, RFSpacing.sm)
            .controlSheetStyle()
            .accessibilityIdentifier("dispatchDraftDiffersBanner")
    }

    private var waitingForGpsRow: some View {
        Text("Waiting for cab GPS…")
            .font(RFFont.caption)
            .foregroundStyle(.secondary)
            .controlSheetStyle()
    }

    @ViewBuilder
    private var fleetRosterSection: some View {
        VStack(alignment: .leading, spacing: RFSpacing.sm) {
            Text("Fleet roster")
                .font(RFFont.sectionTitle)
            if rosterRows.isEmpty {
                Text("No vehicles — bootstrap demo fleet or register cabs.")
                    .font(RFFont.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("Polling \(rosterRows.count) vehicle\(rosterRows.count == 1 ? "" : "s") (active-trip snapshots, not live VU)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                ForEach(rosterRows) { row in
                    Button {
                        onSelectVehicle?(row.vehicleId)
                    } label: {
                        HStack(alignment: .firstTextBaseline, spacing: RFSpacing.sm) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(row.label)
                                    .font(RFFont.caption.weight(.semibold))
                                if let plate = row.plate, !plate.isEmpty {
                                    Text(plate)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer(minLength: 4)
                            Text(DispatchFleetRoster.statusLabel(for: row))
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.secondary)
                            Text(DispatchFleetRoster.formatPhysicsEta(seconds: row.trip?.physicsETASeconds))
                                .font(.caption2.monospacedDigit())
                                .frame(minWidth: 44, alignment: .trailing)
                            Text(DispatchFleetRoster.formatGpsAge(row.gpsAgeSeconds))
                                .font(.caption2.monospacedDigit())
                                .frame(minWidth: 28, alignment: .trailing)
                            if row.hasDefects {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.caption2)
                                    .foregroundStyle(.orange)
                            }
                        }
                        .padding(.vertical, 4)
                        .padding(.horizontal, 8)
                        .background(
                            row.vehicleId == selectedVehicleId
                                ? Color.accentColor.opacity(0.12)
                                : Color.clear,
                            in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .glassPanel(cornerRadius: 14)
        .padding(RFSpacing.sm)
    }

    private func statusHeader(_ trip: FleetTrip) -> some View {
        HStack {
            Text("Active trip")
                .font(RFFont.sectionTitle)
            Spacer()
            if showsTripBriefShare(for: trip) {
                TripBriefShareMenu(
                    context: tripBriefContext(for: trip),
                    labelStyle: .caption
                )
            }
            Text(trip.status.rawValue.capitalized)
                .font(RFFont.caption.weight(.semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color.accentColor.opacity(0.15))
                .clipShape(Capsule())
        }
        .controlSheetStyle()
    }

    private func stopList(_ trip: FleetTrip) -> some View {
        VStack(alignment: .leading, spacing: RFSpacing.sm) {
            Text("Active trip stops")
                .font(RFFont.sectionTitle)
            ForEach(trip.stops.sorted { $0.sequence < $1.sequence }) { stop in
                HStack {
                    Text("\(stop.sequence + 1).")
                        .font(RFFont.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(stop.label)
                            .font(RFFont.caption.weight(.semibold))
                        Text("\(stop.role.rawValue) · \(String(format: "%.4f", stop.latitude)), \(String(format: "%.4f", stop.longitude))")
                            .font(RFFont.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .glassPanel(cornerRadius: 14)
        .padding(RFSpacing.sm)
    }

    private func etaRow(seconds: TimeInterval) -> some View {
        HStack {
            Text("Physics ETA")
                .font(RFFont.sectionTitle)
            Spacer()
            Text(formatDuration(seconds))
                .font(RFFont.summary.monospacedDigit())
        }
        .controlSheetStyle()
    }

    private func showsTripBriefShare(for trip: FleetTrip) -> Bool {
        trip.predictiveReport != nil
            || trip.physicsETASeconds != nil
            || (trip.latestInspectionSummary?.defectCount ?? 0) > 0
    }

    private func inspectionWarningCard(
        _ summary: TripBriefInspectionSummary,
        pdfBase64: String?
    ) -> some View {
        VStack(alignment: .leading, spacing: RFSpacing.xs) {
            HStack {
                Text("Walkaround defects")
                    .font(RFFont.sectionTitle)
                Spacer()
                if let pdfBase64,
                   let pdfData = Data(base64Encoded: pdfBase64),
                   !pdfData.isEmpty {
                    ShareLink(
                        item: pdfData,
                        preview: SharePreview("Walkaround report", icon: Image(systemName: "doc.richtext"))
                    ) {
                        Label("PDF", systemImage: "square.and.arrow.up")
                            .font(RFFont.caption)
                    }
                }
            }
            Text(inspectionSummaryLine(summary))
                .font(RFFont.caption.weight(.semibold))
                .foregroundStyle(.orange)
            Text("Driver-reported defects — verify in the operator defect system before dispatch.")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .controlSheetStyle()
    }

    private func inspectionSummaryLine(_ summary: TripBriefInspectionSummary) -> String {
        let plateSuffix = summary.registrationPlate.map { " (\($0))" } ?? ""
        let timestamp = summary.completedAt.formatted(date: .abbreviated, time: .shortened)
        return "\(summary.vehicleLabel)\(plateSuffix) — \(summary.defectCount) defect(s) at \(timestamp)"
    }

    private func laybyCard(_ advisory: LaybyAdvisory) -> some View {
        VStack(alignment: .leading, spacing: RFSpacing.xs) {
            Text("Predicted layby")
                .font(RFFont.sectionTitle)
            Text(advisory.stop.label)
                .font(RFFont.caption.weight(.semibold))
            if let eta = advisory.estimatedArrivalSeconds {
                Text("ETA ~\(formatDuration(eta)) · occupancy: \(advisory.occupancyPrior.displayLabel)")
                    .font(RFFont.caption)
                    .foregroundStyle(.secondary)
            }
            if let opens = advisory.breakWindowOpensAt {
                Text("Break window opens \(opens.formatted(date: .omitted, time: .shortened))")
                    .font(RFFont.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .controlSheetStyle()
    }

    private func lastPositionRow(_ trip: FleetTrip) -> some View {
        let recordedAt = trip.driverLocationRecordedAt
        let isStale = recordedAt.map { Date().timeIntervalSince($0) > 60 } ?? true
        return HStack(alignment: .firstTextBaseline) {
            Text("Last position")
                .font(RFFont.sectionTitle)
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                if let lat = trip.driverLatitude, let lon = trip.driverLongitude {
                    Text(String(format: "%.5f, %.5f", lat, lon))
                        .font(RFFont.caption.monospacedDigit())
                }
                if let recordedAt {
                    Text(relativeTime(from: recordedAt))
                        .font(.caption2)
                        .foregroundStyle(isStale ? Color.orange : Color.secondary)
                } else {
                    Text("Time unknown")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }
            }
        }
        .controlSheetStyle()
    }

    private func relativeTime(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let totalMinutes = Int(seconds / 60)
        if totalMinutes >= 60 {
            return "\(totalMinutes / 60) h \(totalMinutes % 60) min"
        }
        return "\(max(1, totalMinutes)) min"
    }

    private func telematicsImportCard(_ batch: TelematicsImportBatch) -> some View {
        VStack(alignment: .leading, spacing: RFSpacing.xs) {
            Text("Last telematics import")
                .font(RFFont.sectionTitle)
            Text("\(batch.pings.count) vehicle(s) at \(batch.importedAt.formatted())")
                .font(RFFont.caption)
            Text("Read-only partner export — not legal VU / not live tracking.")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .controlSheetStyle()
    }
}
