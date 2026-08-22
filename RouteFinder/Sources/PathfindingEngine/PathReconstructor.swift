import Contracts
import CostModel
import GraphCore
import Foundation

/// Reconstructs route metrics and turn instructions from search results.
enum PathReconstructor {
    static func buildResult(
        path: [String],
        cameFrom: [String: (String, Edge)],
        nodesVisited: Int,
        runtime: TimeInterval,
        graph: any GraphProtocol,
        algorithmName: String,
        preferences: RoutingPreferences,
        searchCost: Double
    ) -> SearchResult {
        guard path.count >= 2 else {
            return SearchResult(
                path: path,
                totalDistance: 0,
                totalTime: 0,
                nodesVisited: nodesVisited,
                runtime: runtime,
                explanation: "Route found with \(path.count) node(s) via \(algorithmName).",
                metrics: RouteMetrics(
                    totalDistance: 0,
                    totalTime: 0,
                    searchCost: searchCost,
                    speedCameraCount: 0,
                    tollSegmentCount: 0,
                    ferrySegmentCount: 0,
                    tunnelSegmentCount: 0
                )
            )
        }

        var totalDistance = 0.0
        var totalTime = 0.0
        var speedCameraCount = 0
        var tollSegmentCount = 0
        var ferrySegmentCount = 0
        var tunnelSegmentCount = 0
        var edges: [Edge] = []

        for i in 1..<path.count {
            let from = path[i - 1]
            let to = path[i]
            if let edge = findEdge(graph: graph, from: from, to: to) {
                edges.append(edge)
                totalDistance += edge.distance
                totalTime += CostModel.travelTime(for: edge)
                if edge.hasCamera || edge.cameraType != nil { speedCameraCount += 1 }
                if edge.isToll { tollSegmentCount += 1 }
                if edge.isFerry { ferrySegmentCount += 1 }
                if edge.isTunnel { tunnelSegmentCount += 1 }
            }
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

        let instructions = TurnInstructionGenerator.generate(
            path: path,
            edges: edges,
            graph: graph,
            hurryMode: preferences.hurryMode,
            enforceCurveSpeed: preferences.enforceCurveSpeed,
            vehicleWeight: preferences.vehicle.weight
        )

        var explanation = "Route of \(String(format: "%.1f", totalDistance / 1000)) km in \(formatTime(totalTime)) via \(algorithmName)."
        if speedCameraCount > 0 {
            explanation += " \(speedCameraCount) speed camera(s) on route."
        }
        if preferences.hurryMode {
            explanation += " Hurry Mode active."
        }

        return SearchResult(
            path: path,
            totalDistance: totalDistance,
            totalTime: totalTime,
            nodesVisited: nodesVisited,
            runtime: runtime,
            explanation: explanation,
            turnInstructions: instructions,
            metrics: metrics
        )
    }

    static func findEdge(graph: any GraphProtocol, from: String, to: String) -> Edge? {
        graph.neighbors(of: from).first { $0.to == to }
    }

    private static func formatTime(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds) / 60
        if minutes < 60 {
            return "\(minutes) min"
        }
        let hours = minutes / 60
        let remainingMinutes = minutes % 60
        return "\(hours)h \(remainingMinutes)m"
    }
}
