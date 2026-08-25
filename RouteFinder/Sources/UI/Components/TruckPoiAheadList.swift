import Contracts
import SwiftUI

/// Compact list of truck fuel / parking / weigh POIs ahead on the route.
struct TruckPoiAheadList: View {
    let pois: [TruckPoi]
    let isLoading: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: RFSpacing.sm) {
            HStack {
                Text("Truck stops ahead")
                    .font(RFFont.sectionTitle)
                Spacer()
                if isLoading {
                    ProgressView()
                        .controlSize(.small)
                }
            }

            if pois.isEmpty, !isLoading {
                Text("No truck fuel, parking, or weighbridges within 20 mi along route.")
                    .font(RFFont.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(pois.prefix(6)) { poi in
                    HStack(spacing: RFSpacing.sm) {
                        Image(systemName: icon(for: poi.kind))
                            .foregroundStyle(RFColor.route)
                            .frame(width: 20)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(poi.label)
                                .font(RFFont.caption.weight(.semibold))
                                .lineLimit(1)
                            Text(subtitle(for: poi))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 0)
                        if let confidence = poi.confidence {
                            Text(String(format: "%.0f%%", confidence * 100))
                                .font(.caption2.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .padding(RFSpacing.sm)
        .controlSheetStyle()
    }

    private func icon(for kind: TruckPoiKind) -> String {
        switch kind {
        case .highFlowDiesel: "fuelpump.fill"
        case .weighStation: "scalemass.fill"
        case .overnightSecureParking: "parkingsign.circle.fill"
        case .adrCompatibleParking: "exclamationmark.octagon.fill"
        case .layby: "parkingsign"
        }
    }

    private func subtitle(for poi: TruckPoi) -> String {
        let kindLabel: String = switch poi.kind {
        case .highFlowDiesel: "HGV fuel"
        case .weighStation: "Weighbridge"
        case .overnightSecureParking: "Parking"
        case .adrCompatibleParking: "ADR parking"
        case .layby: "Layby"
        }
        if let arc = poi.arcLengthAlongRouteMeters {
            let miles = arc / 1609.34
            return String(format: "%@ · %.1f mi along route", kindLabel, miles)
        }
        return kindLabel
    }
}

/// Banner for an upcoming LEZ / restriction zone.
struct RestrictionZoneBanner: View {
    let announcement: RestrictionZoneAnnouncement

    var body: some View {
        HStack(spacing: RFSpacing.sm) {
<<<<<<< HEAD
            Image(systemName: iconName)
                .foregroundStyle(iconColor)
=======
            Image(systemName: "leaf.circle.fill")
                .foregroundStyle(.green)
>>>>>>> 131ad0b45323f7aa6d871049cbbcf4238fd0ed3b
            Text(announcement.message)
                .font(RFFont.caption.weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, RFSpacing.md)
        .padding(.vertical, RFSpacing.sm)
        .controlSheetStyle()
        .accessibilityLabel(announcement.message)
    }
<<<<<<< HEAD

    private var iconName: String {
        switch announcement.kind {
        case .lez: "leaf.circle.fill"
        case .noDrive, .hgvBanned, .residentialBan: "nosign"
        }
    }

    private var iconColor: Color {
        switch announcement.kind {
        case .lez: .green
        case .noDrive, .hgvBanned, .residentialBan: RFColor.hazard
        }
    }
}

/// Banner prompting the driver to apply a traffic-aware re-route.
struct TrafficRerouteBanner: View {
    let isEvaluating: Bool
    let onRecalculate: () -> Void

    var body: some View {
        HStack(spacing: RFSpacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(RFColor.hazard)
            VStack(alignment: .leading, spacing: 2) {
                Text("Traffic delay")
                    .font(RFFont.caption.weight(.semibold))
                Text(isEvaluating ? "Checking alternate…" : "Congestion detected on corridor")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            if isEvaluating {
                ProgressView()
                    .controlSize(.small)
            } else {
                Button("Recalculate") {
                    onRecalculate()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .tint(RFColor.hazard)
            }
        }
        .padding(.horizontal, RFSpacing.md)
        .padding(.vertical, RFSpacing.sm)
        .controlSheetStyle()
        .accessibilityLabel("Traffic delay. Recalculate route.")
    }
}

=======
}
>>>>>>> 131ad0b45323f7aa6d871049cbbcf4238fd0ed3b
