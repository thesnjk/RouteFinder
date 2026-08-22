#if os(macOS)
import Contracts
import Foundation
import GraphCore

/// Pure-Swift local waypoint sequencing using 2-opt with optional simulated annealing.
public enum LocalWaypointOptimizer {
    /// Optimizes intermediate stop order minimizing total haversine tour distance.
    public static func optimize(request: WaypointOptimizationRequest) -> WaypointOptimizationResult {
        let stopCount = request.intermediateStops.count
        guard stopCount > 1 else {
            return WaypointOptimizationResult(
                optimizedStopIndices: Array(0..<stopCount),
                usedLocalTier: true
            )
        }

        var order = Array(0..<stopCount)
        let allPoints = buildTourPoints(from: request)

        order = twoOptImprove(order: order, points: allPoints, originIndex: 0, destinationIndex: allPoints.count - 1)

        if stopCount > 8 {
            order = simulatedAnnealingImprove(
                order: order,
                points: allPoints,
                originIndex: 0,
                destinationIndex: allPoints.count - 1
            )
        }

        return WaypointOptimizationResult(optimizedStopIndices: order, usedLocalTier: true)
    }

    /// Optimizes intermediate stop order using a precomputed distance matrix.
    public static func optimize(
        request: WaypointOptimizationRequest,
        matrix: [[Double]]
    ) -> WaypointOptimizationResult {
        MatrixWaypointOptimizer.optimize(request: request, matrix: matrix)
    }

    private static func buildTourPoints(from request: WaypointOptimizationRequest) -> [Coordinate] {
        [request.origin.coordinate]
            + request.intermediateStops.map(\.coordinate)
            + [request.destination.coordinate]
    }

    private static func twoOptImprove(
        order: [Int],
        points: [Coordinate],
        originIndex: Int,
        destinationIndex: Int
    ) -> [Int] {
        var bestOrder = order
        var bestDistance = tourDistance(order: bestOrder, points: points, originIndex: originIndex, destinationIndex: destinationIndex)
        var improved = true

        while improved {
            improved = false
            guard bestOrder.count >= 2 else { break }

            for i in 0..<(bestOrder.count - 1) {
                for j in (i + 1)..<bestOrder.count {
                    var candidate = bestOrder
                    candidate[i...j].reverse()
                    let distance = tourDistance(
                        order: candidate,
                        points: points,
                        originIndex: originIndex,
                        destinationIndex: destinationIndex
                    )
                    if distance + 1e-6 < bestDistance {
                        bestDistance = distance
                        bestOrder = candidate
                        improved = true
                    }
                }
            }
        }

        return bestOrder
    }

    private static func simulatedAnnealingImprove(
        order: [Int],
        points: [Coordinate],
        originIndex: Int,
        destinationIndex: Int
    ) -> [Int] {
        var current = order
        var currentDistance = tourDistance(
            order: current,
            points: points,
            originIndex: originIndex,
            destinationIndex: destinationIndex
        )
        var best = current
        var bestDistance = currentDistance

        var temperature = 1000.0
        let coolingRate = 0.995
        let minTemperature = 1.0

        while temperature > minTemperature {
            guard current.count >= 2 else { break }

            var candidate = current
            let i = Int.random(in: 0..<current.count)
            let j = Int.random(in: 0..<current.count)
            if i == j { continue }
            let lower = min(i, j)
            let upper = max(i, j)
            candidate[lower...upper].reverse()

            let candidateDistance = tourDistance(
                order: candidate,
                points: points,
                originIndex: originIndex,
                destinationIndex: destinationIndex
            )
            let delta = candidateDistance - currentDistance

            if delta < 0 || Double.random(in: 0..<1) < exp(-delta / temperature) {
                current = candidate
                currentDistance = candidateDistance
                if candidateDistance < bestDistance {
                    best = candidate
                    bestDistance = candidateDistance
                }
            }

            temperature *= coolingRate
        }

        return best
    }

    private static func tourDistance(
        order: [Int],
        points: [Coordinate],
        originIndex: Int,
        destinationIndex: Int
    ) -> Double {
        var indices = [originIndex]
        indices.append(contentsOf: order.map { $0 + 1 })
        indices.append(destinationIndex)

        var total = 0.0
        for pair in zip(indices, indices.dropFirst()) {
            total += Haversine.distance(from: points[pair.0], to: points[pair.1])
        }
        return total
    }
}
#endif
