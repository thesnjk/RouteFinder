import Contracts
import Foundation

/// Combines multi-stop route legs into a single result.
public enum RouteChainer {
    /// Merges multiple leg results, deduplicating junction nodes.
    public static func combine(legs: [SearchResult]) -> SearchResult {
        guard !legs.isEmpty else { return .empty }

        var combinedPath: [String] = []
        var totalDistance = 0.0
        var totalTime = 0.0
        var searchCost = 0.0
        var speedCameraCount = 0
        var tollSegmentCount = 0
        var ferrySegmentCount = 0
        var tunnelSegmentCount = 0
        var nodesVisited = 0
        var runtime = 0.0
        var turnInstructions: [TurnInstruction] = []

        for (index, leg) in legs.enumerated() {
            if index == 0 {
                combinedPath = leg.path
            } else if let last = combinedPath.last, leg.path.first == last {
                combinedPath.append(contentsOf: leg.path.dropFirst())
            } else {
                combinedPath.append(contentsOf: leg.path)
            }

            totalDistance += leg.totalDistance
            totalTime += leg.totalTime
            searchCost += leg.metrics.searchCost
            speedCameraCount += leg.metrics.speedCameraCount
            tollSegmentCount += leg.metrics.tollSegmentCount
            ferrySegmentCount += leg.metrics.ferrySegmentCount
            tunnelSegmentCount += leg.metrics.tunnelSegmentCount
            nodesVisited += leg.nodesVisited
            runtime += leg.runtime
            turnInstructions.append(contentsOf: leg.turnInstructions)
        }

        let metrics = RouteMetrics(
            totalDistance: totalDistance,
            totalTime: totalTime,
            searchCost: searchCost,
            speedCameraCount: speedCameraCount,
            tollSegmentCount: tollSegmentCount,
            ferrySegmentCount: ferrySegmentCount,
            tunnelSegmentCount: tunnelSegmentCount
        )

        var explanation = "Multi-stop route of \(String(format: "%.1f", totalDistance / 1000)) km in \(formatTime(totalTime)) across \(legs.count) leg(s)."
        if speedCameraCount > 0 {
            explanation += " \(speedCameraCount) speed camera(s) on route."
        }

        return SearchResult(
            path: combinedPath,
            totalDistance: totalDistance,
            totalTime: totalTime,
            nodesVisited: nodesVisited,
            runtime: runtime,
            explanation: explanation,
            turnInstructions: turnInstructions,
            metrics: metrics
        )
    }

    private static func formatTime(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds) / 60
        if minutes < 60 { return "\(minutes) min" }
        return "\(minutes / 60)h \(minutes % 60)m"
    }
}
