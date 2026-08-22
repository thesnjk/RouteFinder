import Contracts
import CoreLocation
import RouteController
import SwiftUI

/// Scrollable turn-by-turn instruction list.
public struct TurnByTurnList: View {
    let instructions: [TurnInstruction]
    let routeReferenceCoordinate: CLLocationCoordinate2D?

    /// Creates a turn-by-turn list with optional route coordinate for regional speed formatting.
    public init(
        instructions: [TurnInstruction],
        routeReferenceCoordinate: CLLocationCoordinate2D? = nil
    ) {
        self.instructions = instructions
        self.routeReferenceCoordinate = routeReferenceCoordinate
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Turn-by-Turn")
                .font(.headline)
                .vibrancyLabel()

            if instructions.isEmpty {
                Text("No instructions yet.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(instructions) { instruction in
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: symbol(for: instruction.maneuver))
                                    .foregroundStyle(
                                        instruction.maneuver == .speedCamera || instruction.maneuver == .averageSpeedZone
                                            ? .orange : .primary
                                    )
                                    .frame(width: 24)
                                VStack(alignment: .leading) {
                                    Text(label(for: instruction))
                                        .font(.subheadline)
                                        .vibrancyLabel()
                                    if let road = instruction.roadName {
                                        Text(road)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    if instruction.distance > 0 {
                                        Text(String(format: "%.0f m", instruction.distance))
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                    if let speed = instruction.recommendedSpeedKmh {
                                        Text("Recommended \(formattedRecommendedSpeed(speed))")
                                            .font(.caption2)
                                            .foregroundStyle(.orange)
                                    }
                                }
                            }
                        }
                    }
                }
                .frame(maxHeight: 200)
            }
        }
    }

    private func formattedRecommendedSpeed(_ speedKmh: Double) -> String {
        if let coordinate = routeReferenceCoordinate {
            return TelemetryUnitConverter.formatSpeedKmh(speedKmh, at: coordinate)
        }
        return TelemetryUnitConverter.formatSpeedKmh(speedKmh, system: .metric)
    }

    private func label(for instruction: TurnInstruction) -> String {
        switch instruction.maneuver {
        case .speedCamera:
            return "Speed camera ahead"
        case .averageSpeedZone:
            return "Average speed zone"
        case .depart:
            return "Depart"
        case .arrive:
            return "Arrive at destination"
        default:
            if let road = instruction.roadName, instruction.distance > 0 {
                return "\(instruction.maneuver.rawValue.capitalized) — continue on \(road)"
            }
            return instruction.maneuver.rawValue.capitalized
        }
    }

    private func symbol(for maneuver: TurnManeuver) -> String {
        switch maneuver {
        case .depart: return "location.fill"
        case .straight: return "arrow.up"
        case .slightLeft: return "arrow.up.left"
        case .left: return "turn.left"
        case .sharpLeft: return "arrow.turn.up.left"
        case .slightRight: return "arrow.up.right"
        case .right: return "turn.right"
        case .sharpRight: return "arrow.turn.up.right"
        case .uTurn: return "arrow.uturn.down"
        case .roundabout: return "arrow.triangle.2.circlepath"
        case .speedCamera: return "camera.fill"
        case .averageSpeedZone: return "camera.metering.multiple"
        case .arrive: return "flag.checkered"
        }
    }
}
