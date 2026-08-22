import Contracts
import CostModel
import Foundation

/// Generates turn-by-turn instructions from a path and its edges.
enum TurnInstructionGenerator {
    static func generate(
        path: [String],
        edges: [Edge],
        graph: any GraphProtocol,
        hurryMode: Bool = false,
        enforceCurveSpeed: Bool = false,
        vehicleWeight: Double? = nil
    ) -> [TurnInstruction] {
        guard !path.isEmpty else { return [] }

        var instructions: [TurnInstruction] = []

        if graph.node(id: path[0]) != nil {
            instructions.append(TurnInstruction(
                maneuver: .depart,
                roadName: edges.first?.roadName,
                distance: 0,
                bearing: bearingForSegment(fromIndex: 0, path: path, graph: graph)
            ))
        }

        for i in 0..<edges.count {
            let edge = edges[i]
            let segmentBearing = bearingForEdge(edge: edge, path: path, edgeIndex: i, graph: graph)

            if edge.hasCamera || edge.cameraType != nil {
                let cameraManeuver: TurnManeuver
                if edge.cameraType == .averageSpeedZone {
                    cameraManeuver = .averageSpeedZone
                } else {
                    cameraManeuver = .speedCamera
                }
                if hurryMode || edge.cameraType == .averageSpeedZone {
                    instructions.append(TurnInstruction(
                        maneuver: cameraManeuver,
                        roadName: edge.roadName,
                        distance: edge.distance,
                        bearing: segmentBearing
                    ))
                }
            }

            let maneuver: TurnManeuver
            let turnAngle: Double
            if i == 0 {
                maneuver = .straight
                turnAngle = 0
            } else {
                let prevBearing = bearingForEdge(edge: edges[i - 1], path: path, edgeIndex: i - 1, graph: graph)
                turnAngle = normalizedTurnAngle(from: prevBearing, to: segmentBearing)
                maneuver = classifyTurn(from: prevBearing, to: segmentBearing)
            }

            let recommendedSpeed = enforceCurveSpeed
                ? CurveSpeedAdvisor.recommendedSpeedKmh(
                    turnAngleDegrees: turnAngle,
                    vehicleWeightTonnes: vehicleWeight,
                    edgeSpeedKmh: edge.speed
                )
                : nil

            instructions.append(TurnInstruction(
                maneuver: maneuver,
                roadName: edge.roadName,
                distance: edge.distance,
                bearing: segmentBearing,
                recommendedSpeedKmh: recommendedSpeed
            ))
        }

        if path.count > 1 {
            instructions.append(TurnInstruction(
                maneuver: .arrive,
                roadName: nil,
                distance: 0,
                bearing: bearingForSegment(fromIndex: path.count - 2, path: path, graph: graph)
            ))
        }

        return instructions
    }

    private static func bearingForEdge(
        edge: Edge,
        path: [String],
        edgeIndex: Int,
        graph: any GraphProtocol
    ) -> Double {
        bearingForSegment(fromIndex: edgeIndex, path: path, graph: graph)
    }

    private static func bearingForSegment(
        fromIndex: Int,
        path: [String],
        graph: any GraphProtocol
    ) -> Double {
        guard fromIndex + 1 < path.count,
              let from = graph.node(id: path[fromIndex]),
              let to = graph.node(id: path[fromIndex + 1]) else { return 0 }

        let lat1 = from.latitude * .pi / 180
        let lat2 = to.latitude * .pi / 180
        let dLon = (to.longitude - from.longitude) * .pi / 180

        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
        let bearing = atan2(y, x) * 180 / .pi
        return (bearing + 360).truncatingRemainder(dividingBy: 360)
    }

    private static func normalizedTurnAngle(from: Double, to: Double) -> Double {
        var diff = to - from
        while diff > 180 { diff -= 360 }
        while diff < -180 { diff += 360 }
        return abs(diff)
    }

    private static func classifyTurn(from: Double, to: Double) -> TurnManeuver {
        var diff = to - from
        while diff > 180 { diff -= 360 }
        while diff < -180 { diff += 360 }

        switch diff {
        case -180..<(-135): return .uTurn
        case -135..<(-45): return .left
        case -45..<(-15): return .slightLeft
        case -15...15: return .straight
        case 15..<45: return .slightRight
        case 45..<135: return .right
        default: return .sharpRight
        }
    }
}
