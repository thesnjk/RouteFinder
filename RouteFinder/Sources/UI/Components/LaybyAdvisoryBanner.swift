import Contracts
import SwiftUI

/// Banner announcing an upcoming layby with driver occupancy feedback actions.
struct LaybyAdvisoryBanner: View {
    let advisory: LaybyAdvisory
    var onLaybyFull: () -> Void
    var onLaybyHasSpaces: () -> Void = {}

    var body: some View {
        HStack(spacing: RFSpacing.md) {
            Image(systemName: "parkingsign.circle.fill")
                .font(.title3)
                .foregroundStyle(.tint)

            VStack(alignment: .leading, spacing: 4) {
                Text(primaryLine)
                    .font(RFFont.sectionTitle)
                    .fixedSize(horizontal: false, vertical: true)
                Text(advisory.stop.label)
                    .font(RFFont.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                if !detailLine.isEmpty {
                    Text(detailLine)
                        .font(RFFont.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if advisory.isAdvisory {
                    Text("Advisory — digital tachograph remains the legal record.")
                        .font(RFFont.caption)
                        .foregroundStyle(.tertiary)
                }

                HStack(spacing: RFSpacing.sm) {
                    Button("Looks full") {
                        onLaybyFull()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                    Button("Has spaces") {
                        onLaybyHasSpaces()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)

                    Link(
                        "Find parking (TRAVIS)",
                        destination: ParkingPartnerLinks.travisURL(
                            latitude: advisory.stop.coordinate.latitude,
                            longitude: advisory.stop.coordinate.longitude,
                            label: advisory.stop.label
                        )
                    )
                    .font(RFFont.caption)
                    .controlSize(.small)
                }
                .padding(.top, 2)
                Text("Opens partner site — booking and fees are between you and the operator.")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Spacer(minLength: RFSpacing.sm)
        }
        .padding(RFSpacing.md)
        .controlSheetStyle()
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilitySummary)
    }

    private var primaryLine: String {
        "You will need to stop at \(advisory.stop.label) in \(formattedETA) / \(formattedDistance)"
    }

    private var detailLine: String {
        var parts: [String] = []
        if let opensAt = advisory.breakWindowOpensAt {
            parts.append("break window opens at \(formattedTime(opensAt))")
        }
        parts.append("occupancy prior: \(advisory.occupancyPrior.displayLabel)")
        if let lastSeen = lastSeenLine {
            parts.append(lastSeen)
        }
        return parts.joined(separator: "; ")
    }

    private var lastSeenLine: String? {
        guard let at = advisory.lastOccupancyReportAt,
              let kind = advisory.lastOccupancyKind else {
            return nil
        }
        let kindLabel: String
        switch kind {
        case .full: kindLabel = "full"
        case .spacesAvailable: kindLabel = "spaces"
        }
        return "last seen \(kindLabel) · \(relativeAge(since: at))"
    }

    private func relativeAge(since date: Date, now: Date = Date()) -> String {
        let seconds = max(0, now.timeIntervalSince(date))
        if seconds < 60 {
            return "just now"
        }
        let minutes = Int(seconds / 60)
        if minutes < 60 {
            return "\(minutes) min ago"
        }
        let hours = Int(seconds / 3_600)
        if hours < 24 {
            return hours == 1 ? "1 h ago" : "\(hours) h ago"
        }
        let days = Int(seconds / 86_400)
        return days == 1 ? "1 day ago" : "\(days) days ago"
    }

    private var formattedDistance: String {
        let meters = advisory.distanceRemainingMeters
        if meters >= 1000 {
            return String(format: "%.0f mi", meters / 1609.34)
        }
        return String(format: "%.0f m", meters)
    }

    private var formattedETA: String {
        guard let seconds = advisory.estimatedArrivalSeconds, seconds > 0 else {
            return "—"
        }
        let minutes = Int((seconds / 60).rounded())
        if minutes >= 60 {
            let hours = minutes / 60
            let remainder = minutes % 60
            return remainder == 0 ? "~\(hours) h" : "~\(hours) h \(remainder) min"
        }
        return "~\(max(1, minutes)) min"
    }

    private func formattedTime(_ date: Date) -> String {
        advisoryTimeFormatter.string(from: date)
    }

    private var accessibilitySummary: String {
        var summary = primaryLine
        if !detailLine.isEmpty {
            summary += ". \(detailLine)"
        }
        if advisory.isAdvisory {
            summary += ". Advisory only."
        }
        return summary
    }

    private var advisoryTimeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter
    }
}

/// Compact HUD banner for live kinetic advisories during simulation or navigation.
struct LiveKineticAdvisoryBanner: View {
    let text: String

    var body: some View {
        HStack(spacing: RFSpacing.sm) {
            Image(systemName: "flame.fill")
                .font(.body.weight(.semibold))
                .foregroundStyle(RFColor.hazard)
            Text(text)
                .font(RFFont.caption.weight(.semibold))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, RFSpacing.md)
        .padding(.vertical, RFSpacing.sm)
        .controlSheetStyle()
        .accessibilityLabel(text)
    }
}

/// Unified predictive risk banner (fused kinetic / weather / hazard / roadworks / traffic).
struct PredictiveRiskPrimaryBanner: View {
    let advisory: RouteRiskAdvisory

    var body: some View {
        HStack(spacing: RFSpacing.sm) {
            Image(systemName: iconName)
                .font(.body.weight(.semibold))
                .foregroundStyle(iconColor)
            Text(advisory.message)
                .font(RFFont.caption.weight(.semibold))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, RFSpacing.md)
        .padding(.vertical, RFSpacing.sm)
        .controlSheetStyle()
        .accessibilityLabel(advisory.message)
        .accessibilityIdentifier("predictiveRiskPrimaryBanner")
    }

    private var iconName: String {
        switch advisory.kind {
        case .kinetic: "flame.fill"
        case .weather: "cloud.rain.fill"
        case .traffic: "car.2.fill"
        case .roadworks: "cone.fill"
        case .hazard: "exclamationmark.triangle.fill"
        case .clearance: "arrow.up.and.down"
        }
    }

    private var iconColor: Color {
        switch advisory.severity {
        case .info: .secondary
        case .caution: .orange
        case .severe: RFColor.hazard
        }
    }
}
