import Contracts
import CoreLocation
import SwiftUI

/// Dispatch detail: trip status, physics ETA, telemetry, predicted layby.
struct DispatchStatusPanel: View {
    let trip: FleetTrip?
    let vehicleLabel: String?
    let previewCoordinates: [CLLocationCoordinate2D]

    init(
        trip: FleetTrip?,
        vehicleLabel: String? = nil,
        previewCoordinates: [CLLocationCoordinate2D] = []
    ) {
        self.trip = trip
        self.vehicleLabel = vehicleLabel
        self.previewCoordinates = previewCoordinates
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
                if let trip {
                    statusHeader(trip)
                    stopList(trip)
                    if let seconds = trip.physicsETASeconds {
                        etaRow(seconds: seconds)
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

    private func statusHeader(_ trip: FleetTrip) -> some View {
        HStack {
            Text("Status")
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
            Text("Stops")
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

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let totalMinutes = Int(seconds / 60)
        if totalMinutes >= 60 {
            return "\(totalMinutes / 60) h \(totalMinutes % 60) min"
        }
        return "\(max(1, totalMinutes)) min"
    }
}
