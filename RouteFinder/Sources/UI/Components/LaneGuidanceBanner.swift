import Contracts
import SwiftUI

/// Map-top lane guidance banner with maneuver distance and lane strip.
public struct LaneGuidanceBanner: View {
    public let guidance: LaneGuidance
    public let maneuver: TurnManeuver
    public let distanceMeters: Double

    /// Creates a lane guidance banner.
    public init(guidance: LaneGuidance, maneuver: TurnManeuver, distanceMeters: Double) {
        self.guidance = guidance
        self.maneuver = maneuver
        self.distanceMeters = distanceMeters
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: RFSpacing.sm) {
            HStack(spacing: RFSpacing.sm) {
                Image(systemName: maneuverSymbol)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(RFColor.route)
                Text(distanceLabel)
                    .font(RFFont.caption.weight(.semibold))
                Spacer(minLength: 0)
                Text(guidance.guidanceText)
                    .font(RFFont.caption)
                    .foregroundStyle(.secondary)
            }

            Text(guidance.source == .osm ? "Lane data: OSM" : "Lane data: estimate")
                .font(.caption2)
                .foregroundStyle(.tertiary)

            HStack(spacing: 6) {
                ForEach(Array(guidance.lanes.enumerated()), id: \.offset) { index, lane in
                    laneTile(lane: lane, highlighted: guidance.recommendedIndices.contains(index))
                }
            }
        }
        .padding(.horizontal, RFSpacing.md)
        .padding(.vertical, RFSpacing.sm)
        .glassPanel(cornerRadius: 14)
    }

    private var distanceLabel: String {
        if distanceMeters >= 1000 {
            return String(format: "In %.1f km", distanceMeters / 1000)
        }
        return "In \(Int(distanceMeters)) m"
    }

    private var maneuverSymbol: String {
        switch maneuver {
        case .left, .sharpLeft, .slightLeft: return "arrow.turn.up.left"
        case .right, .sharpRight, .slightRight: return "arrow.turn.up.right"
        case .uTurn: return "arrow.uturn.left"
        case .roundabout: return "arrow.triangle.2.circlepath"
        case .arrive: return "flag.checkered"
        default: return "arrow.up"
        }
    }

    @ViewBuilder
    private func laneTile(lane: LaneArrow, highlighted: Bool) -> some View {
        VStack(spacing: 2) {
            Image(systemName: laneSymbol(for: lane))
                .font(.caption.weight(.bold))
            Capsule()
                .fill(highlighted ? RFColor.route : Color.secondary.opacity(0.35))
                .frame(height: 3)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .padding(.horizontal, 4)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(highlighted ? RFColor.route.opacity(0.18) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(highlighted ? RFColor.route.opacity(0.65) : Color.secondary.opacity(0.25), lineWidth: 1)
        )
    }

    private func laneSymbol(for lane: LaneArrow) -> String {
        switch lane {
        case .straight: return "arrow.up"
        case .slightLeft: return "arrow.up.left"
        case .left: return "arrow.turn.up.left"
        case .slightRight: return "arrow.up.right"
        case .right: return "arrow.turn.up.right"
        case .merge: return "arrow.merge"
        case .unknown: return "questionmark"
        }
    }
}
