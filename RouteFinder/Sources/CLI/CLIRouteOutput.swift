import Contracts
import Foundation
import RouteController
import SharedCore

struct CLIRouteMetricsOutput: Encodable {
    let totalDistance: Double
    let totalTime: Double
    let searchCost: Double
    let speedCameraCount: Int
    let tollSegmentCount: Int
    let ferrySegmentCount: Int
    let tunnelSegmentCount: Int

    init(_ metrics: RouteMetrics) {
        totalDistance = metrics.totalDistance
        totalTime = metrics.totalTime
        searchCost = metrics.searchCost
        speedCameraCount = metrics.speedCameraCount
        tollSegmentCount = metrics.tollSegmentCount
        ferrySegmentCount = metrics.ferrySegmentCount
        tunnelSegmentCount = metrics.tunnelSegmentCount
    }
}

struct CLIRouteOutput: Encodable {
    let path: [String]
    let totalDistance: Double
    let totalTime: Double
    let nodesVisited: Int
    let runtime: Double
    let explanation: String
    let turnInstructions: [TurnInstruction]
    let metrics: CLIRouteMetricsOutput
    let encodedPolyline: String?
    let polylinePrecision: Int?
    let coordinates: [Coordinate]?
    let weather: String?
    let environmentalContext: String?

    init(searchResult: SearchResult, externalResponse: ExternalRouteResponse? = nil, weatherRequest: WeatherAwareRoutingRequest? = nil) {
        path = searchResult.path
        totalDistance = searchResult.totalDistance
        totalTime = searchResult.totalTime
        nodesVisited = searchResult.nodesVisited
        runtime = searchResult.runtime
        explanation = searchResult.explanation
        turnInstructions = searchResult.turnInstructions
        metrics = CLIRouteMetricsOutput(searchResult.metrics)
        encodedPolyline = externalResponse?.encodedPolyline
        polylinePrecision = externalResponse?.encodedPolyline == nil ? nil : externalResponse?.polylinePrecision
        coordinates = externalResponse?.coordinates
        weather = weatherRequest?.weather.rawValue
        environmentalContext = weatherRequest?.environmentalContext.rawValue
    }
}

enum CLIRouteFormatter {
    static func printHuman(_ result: SearchResult, externalResponse: ExternalRouteResponse? = nil, weatherRequest: WeatherAwareRoutingRequest? = nil) {
        let distanceLabel = formatDistance(result.totalDistance)
        let durationLabel = formatDuration(result.totalTime)

        print("Route: \(result.explanation)")
        if let weatherRequest {
            print("Weather: \(weatherRequest.weather.rawValue) (µ=\(weatherRequest.environmentalContext.frictionCoefficient))")
        }
        print("Distance: \(distanceLabel)")
        print("Duration: \(durationLabel)")
        print("Nodes visited: \(result.nodesVisited)")

        if !result.path.isEmpty {
            print("Path: \(result.path.joined(separator: " → "))")
        }

        if let externalResponse {
            print("Geometry points: \(externalResponse.coordinates.count)")
            if let polyline = externalResponse.encodedPolyline {
                print("Encoded polyline: \(polyline.prefix(80))\(polyline.count > 80 ? "…" : "")")
            }
        }

        if !result.turnInstructions.isEmpty {
            print("Turn instructions:")
            for (index, instruction) in result.turnInstructions.enumerated() {
                let road = instruction.roadName.map { " on \($0)" } ?? ""
                print("  \(index + 1). \(instruction.maneuver.rawValue)\(road) (\(formatDistance(instruction.distance)))")
            }
        }
    }

    static func printJSON(_ result: SearchResult, externalResponse: ExternalRouteResponse? = nil, weatherRequest: WeatherAwareRoutingRequest? = nil) throws {
        let output = CLIRouteOutput(searchResult: result, externalResponse: externalResponse, weatherRequest: weatherRequest)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(output)
        guard let text = String(data: data, encoding: .utf8) else {
            throw EncodingError.invalidValue(
                output,
                EncodingError.Context(codingPath: [], debugDescription: "UTF-8 encoding failed")
            )
        }
        print(text)
    }

    private static func formatDistance(_ meters: Double) -> String {
        meters >= 1000
            ? String(format: "%.1f km", meters / 1000)
            : String(format: "%.0f m", meters)
    }

    private static func formatDuration(_ seconds: TimeInterval) -> String {
        let totalMinutes = Int(seconds / 60)
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        if hours > 0 {
            return "\(hours) h \(minutes) min"
        }
        return "\(max(1, minutes)) min"
    }
}

enum CLIExit {
    static func usage(_ message: String? = nil) -> Never {
        if let message {
            fputs("Error: \(message)\n", stderr)
        }
        CLIUsage.printUsage()
        exit(1)
    }

    static func routingFailure(_ error: Error) -> Never {
        fputs("Routing failed: \(error.localizedDescription)\n", stderr)
        exit(2)
    }
}
