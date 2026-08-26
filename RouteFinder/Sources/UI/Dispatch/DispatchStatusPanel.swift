import Contracts
import SwiftUI

/// Dispatch detail: trip status, physics ETA, telemetry, predicted layby.
struct DispatchStatusPanel: View {
    let trip: FleetTrip?
    let vehicleLabel: String?

    init(trip: FleetTrip?, vehicleLabel: String? = nil) {
        self.trip = trip
        self.vehicleLabel = vehicleLabel
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
                            briefContext: TripBriefContext.from(fleetTrip: trip, vehicleLabel: vehicleLabel)
                        )
                    }
                    if let layby = trip.predictedLayby {
                        laybyCard(layby)
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
            if trip.predictiveReport != nil || trip.physicsETASeconds != nil {
                ShareLink(
                    item: TripBriefFormatter.plainText(
                        from: TripBriefContext.from(fleetTrip: trip, vehicleLabel: vehicleLabel)
                    )
                ) {
                    Label("Share brief", systemImage: "square.and.arrow.up")
                        .font(RFFont.caption)
                }
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
