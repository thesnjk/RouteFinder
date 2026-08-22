import Contracts
import Foundation

/// Cross-platform 2-opt waypoint sequencing using a precomputed distance matrix.
public enum MatrixWaypointOptimizer {
    /// Optimizes intermediate stop order using the provided distance matrix.
    public static func optimize(
        request: WaypointOptimizationRequest,
        matrix: [[Double]]
    ) -> WaypointOptimizationResult {
        let stopCount = request.intermediateStops.count
        guard stopCount > 1 else {
            return WaypointOptimizationResult(
                optimizedStopIndices: Array(0..<stopCount),
                usedLocalTier: true
            )
        }

        let pointCount = stopCount + 2
        guard matrix.count == pointCount, matrix.allSatisfy({ $0.count == pointCount }) else {
            return WaypointOptimizationResult(
                optimizedStopIndices: Array(0..<stopCount),
                usedLocalTier: true
            )
        }

        var order = Array(0..<stopCount)
        order = twoOptImprove(order: order, matrix: matrix, originIndex: 0, destinationIndex: pointCount - 1)
        return WaypointOptimizationResult(optimizedStopIndices: order, usedLocalTier: true)
    }

    private static func twoOptImprove(
        order: [Int],
        matrix: [[Double]],
        originIndex: Int,
        destinationIndex: Int
    ) -> [Int] {
        var bestOrder = order
        var bestDistance = tourDistance(
            order: bestOrder,
            matrix: matrix,
            originIndex: originIndex,
            destinationIndex: destinationIndex
        )
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
                        matrix: matrix,
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

    private static func tourDistance(
        order: [Int],
        matrix: [[Double]],
        originIndex: Int,
        destinationIndex: Int
    ) -> Double {
        var indices = [originIndex]
        indices.append(contentsOf: order.map { $0 + 1 })
        indices.append(destinationIndex)

        var total = 0.0
        for pair in zip(indices, indices.dropFirst()) {
            total += matrix[pair.0][pair.1]
        }
        return total
    }
}
