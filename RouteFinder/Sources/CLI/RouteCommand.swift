import Contracts
import DataLayer
import Foundation
import GraphCore
import RouteController
import SharedCore

enum RouteCommand {
    struct Options {
        var graphDirectory: String?
        var fromNodeID: String?
        var toNodeID: String?
        var origin: RoutingCoordinate?
        var destination: RoutingCoordinate?
        var viaCoordinates: [RoutingCoordinate] = []
        var algorithm: RoutingAlgorithm = .aStar
        var orsAPIKey: String?
        var isHGVMode = false
        var vehicleHeight: Double?
        var vehicleWeight: Double?
        var vehicleWidth: Double?
        var weatherOverride: WeatherCondition?
        var emitJSON = false
    }

    static func run(_ args: [String]) async {
        let options: Options
        do {
            options = try parse(args)
        } catch {
            CLIExit.usage(error.localizedDescription)
        }

        do {
            if let graphDirectory = options.graphDirectory {
                try await runLocalRoute(options: options, graphDirectory: graphDirectory)
            } else if let origin = options.origin, let destination = options.destination {
                try await runORSRoute(options: options, origin: origin, destination: destination)
            } else {
                CLIExit.usage("Provide either --graph with --from/--to, or --origin with --destination.")
            }
        } catch {
            CLIExit.routingFailure(error)
        }
    }

    private static func parse(_ args: [String]) throws -> Options {
        var options = Options()
        var index = 0

        while index < args.count {
            let flag = args[index]
            switch flag {
            case "--graph":
                index += 1
                guard index < args.count else { throw ParseError.missingValue("--graph") }
                options.graphDirectory = args[index]
            case "--from":
                index += 1
                guard index < args.count else { throw ParseError.missingValue("--from") }
                options.fromNodeID = args[index]
            case "--to":
                index += 1
                guard index < args.count else { throw ParseError.missingValue("--to") }
                options.toNodeID = args[index]
            case "--origin":
                index += 1
                guard index < args.count else { throw ParseError.missingValue("--origin") }
                options.origin = try CoordinateParsing.parseLatLon(args[index])
            case "--destination":
                index += 1
                guard index < args.count else { throw ParseError.missingValue("--destination") }
                options.destination = try CoordinateParsing.parseLatLon(args[index])
            case "--via":
                index += 1
                guard index < args.count else { throw ParseError.missingValue("--via") }
                options.viaCoordinates.append(try CoordinateParsing.parseLatLon(args[index]))
            case "--algorithm":
                index += 1
                guard index < args.count else { throw ParseError.missingValue("--algorithm") }
                switch args[index].lowercased() {
                case "astar", "a-star", "a*":
                    options.algorithm = .aStar
                case "dijkstra":
                    options.algorithm = .dijkstra
                default:
                    throw ParseError.invalidValue("--algorithm", args[index])
                }
            case "--ors-key":
                index += 1
                guard index < args.count else { throw ParseError.missingValue("--ors-key") }
                options.orsAPIKey = args[index]
            case "--weather":
                index += 1
                guard index < args.count else { throw ParseError.missingValue("--weather") }
                guard let weather = WeatherCondition(cliText: args[index]) else {
                    throw ParseError.invalidValue("--weather", args[index])
                }
                options.weatherOverride = weather
            case "--hgv":
                options.isHGVMode = true
            case "--height":
                index += 1
                guard index < args.count else { throw ParseError.missingValue("--height") }
                options.vehicleHeight = try parsePositiveDouble(args[index], flag: "--height")
            case "--weight":
                index += 1
                guard index < args.count else { throw ParseError.missingValue("--weight") }
                options.vehicleWeight = try parsePositiveDouble(args[index], flag: "--weight")
            case "--width":
                index += 1
                guard index < args.count else { throw ParseError.missingValue("--width") }
                options.vehicleWidth = try parsePositiveDouble(args[index], flag: "--width")
            case "--json":
                options.emitJSON = true
            case "--help", "-h":
                CLIUsage.printUsage()
                exit(0)
            default:
                throw ParseError.unknownFlag(flag)
            }
            index += 1
        }

        if options.orsAPIKey == nil {
            let envKey = ProcessInfo.processInfo.environment["ORS_API_KEY"]?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if let envKey, !envKey.isEmpty {
                options.orsAPIKey = envKey
            }
        }

        return options
    }

    private static func runLocalRoute(options: Options, graphDirectory: String) async throws {
        guard let fromNodeID = options.fromNodeID, !fromNodeID.isEmpty else {
            CLIExit.usage("--from is required for local graph routing.")
        }
        guard let toNodeID = options.toNodeID, !toNodeID.isEmpty else {
            CLIExit.usage("--to is required for local graph routing.")
        }

        let nodesPath = graphDirectory.hasSuffix(".csv")
            ? graphDirectory
            : "\(graphDirectory)/nodes.csv"
        let edgesPath: String
        if graphDirectory.hasSuffix("nodes.csv") {
            edgesPath = graphDirectory.replacingOccurrences(of: "nodes.csv", with: "edges.csv")
        } else if graphDirectory.hasSuffix(".csv") {
            edgesPath = graphDirectory
        } else {
            edgesPath = "\(graphDirectory)/edges.csv"
        }

        let loader = GraphLoader()
        let graph = try await loader.load(nodesPath: nodesPath, edgesPath: edgesPath)
        let startLocation = graph.node(id: fromNodeID).map {
            RoutingCoordinate(latitude: $0.latitude, longitude: $0.longitude)
        }
        let weatherRequest = try await resolveWeatherRequest(options: options, startLocation: startLocation)
        let preferences = makePreferences(options: options)
        let planner = RoutePlanner()

        let result = try await planner.calculateRoute(
            graph: graph,
            from: fromNodeID,
            to: toNodeID,
            preferences: preferences
        )

        emitResult(result, externalResponse: nil, weatherRequest: weatherRequest, emitJSON: options.emitJSON)
    }

    private static func runORSRoute(
        options: Options,
        origin: RoutingCoordinate,
        destination: RoutingCoordinate
    ) async throws {
        guard let apiKey = options.orsAPIKey, !apiKey.isEmpty else {
            CLIExit.usage("OpenRouteService routing requires --ors-key or ORS_API_KEY.")
        }

        let weatherRequest = try await resolveWeatherRequest(options: options, startLocation: origin)
        let preferences = makePreferences(options: options)
        let vehicle = makeVehicleProfile(options: options)
        let externalRequest = ExternalRouteRequest(
            origin: origin,
            destination: destination,
            waypoints: options.viaCoordinates,
            vehicle: vehicle,
            preferences: preferences
        )

        let client = try OpenRouteServiceRoutingClient(apiKey: apiKey)
        let planner = RoutePlanner(externalClient: client)
        let (result, response) = try await planner.calculateExternalRoute(request: externalRequest)
        emitResult(result, externalResponse: response, weatherRequest: weatherRequest, emitJSON: options.emitJSON)
    }

    private static func resolveWeatherRequest(
        options: Options,
        startLocation: RoutingCoordinate?
    ) async throws -> WeatherAwareRoutingRequest {
        if options.weatherOverride != nil || startLocation != nil {
            let service = try makeWeatherService(needsFetch: options.weatherOverride == nil)
            return try await WeatherResolver.makeRequest(
                override: options.weatherOverride,
                startLocation: startLocation,
                service: service
            )
        }
        return WeatherAwareRoutingRequest(weather: .dry, startLocation: nil)
    }

    private static func makeWeatherService(needsFetch: Bool) throws -> any WeatherService {
        if needsFetch {
            return try OpenWeatherClient()
        }
        return DryWeatherService()
    }

    private static func makePreferences(options: Options) -> RoutingPreferences {
        RoutingPreferences(
            isHGVMode: options.isHGVMode,
            avoidResidential: true,
            vehicle: makeVehicleProfile(options: options),
            algorithm: options.algorithm
        )
    }

    private static func makeVehicleProfile(options: Options) -> VehicleProfile {
        if options.isHGVMode {
            return VehicleProfile(
                height: options.vehicleHeight ?? VehicleProfile.ukArtic.height,
                weight: options.vehicleWeight ?? VehicleProfile.ukArtic.weight,
                width: options.vehicleWidth ?? VehicleProfile.ukArtic.width,
                length: VehicleProfile.ukArtic.length
            )
        }
        return VehicleProfile(
            height: options.vehicleHeight,
            weight: options.vehicleWeight,
            width: options.vehicleWidth
        )
    }

    private static func emitResult(
        _ result: SearchResult,
        externalResponse: ExternalRouteResponse?,
        weatherRequest: WeatherAwareRoutingRequest,
        emitJSON: Bool
    ) {
        if emitJSON {
            do {
                try CLIRouteFormatter.printJSON(result, externalResponse: externalResponse, weatherRequest: weatherRequest)
            } catch {
                CLIExit.routingFailure(error)
            }
        } else {
            CLIRouteFormatter.printHuman(result, externalResponse: externalResponse, weatherRequest: weatherRequest)
        }
    }

    private static func parsePositiveDouble(_ text: String, flag: String) throws -> Double {
        guard let value = Double(text), value > 0 else {
            throw ParseError.invalidValue(flag, text)
        }
        return value
    }

    enum ParseError: Error, LocalizedError {
        case missingValue(String)
        case unknownFlag(String)
        case invalidValue(String, String)

        var errorDescription: String? {
            switch self {
            case .missingValue(let flag):
                return "Missing value for \(flag)."
            case .unknownFlag(let flag):
                return "Unknown option: \(flag)."
            case .invalidValue(let flag, let value):
                return "Invalid value for \(flag): \(value)."
            }
        }
    }
}

private struct DryWeatherService: WeatherService {
    func fetchCurrent(at location: RoutingCoordinate) async throws -> WeatherCondition {
        .dry
    }
}
