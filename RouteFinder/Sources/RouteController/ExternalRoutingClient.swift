import Contracts
import Foundation

/// Request payload for external OpenRouteService/OSRM routing.
public struct ExternalRouteRequest: Sendable, Codable {
    public let origin: RoutingCoordinate
    public let destination: RoutingCoordinate
    public let waypoints: [RoutingCoordinate]
    public let vehicle: VehicleProfile
    public let preferences: RoutingPreferences

    /// Creates an external routing request from routing-safe coordinates only.
    public init(
        origin: RoutingCoordinate,
        destination: RoutingCoordinate,
        waypoints: [RoutingCoordinate] = [],
        vehicle: VehicleProfile,
        preferences: RoutingPreferences
    ) {
        self.origin = origin
        self.destination = destination
        self.waypoints = waypoints
        self.vehicle = vehicle
        self.preferences = preferences
    }

    /// Returns a copy with segment speed limit requests disabled.
    func omittingExtraInfo() -> ExternalRouteRequest {
        ExternalRouteRequest(
            origin: origin,
            destination: destination,
            waypoints: waypoints,
            vehicle: vehicle,
            preferences: RoutingPreferences(
                optimizationMode: preferences.optimizationMode,
                avoidTolls: preferences.avoidTolls,
                avoidFerries: preferences.avoidFerries,
                avoidTunnels: preferences.avoidTunnels,
                hurryMode: preferences.hurryMode,
                isHGVMode: preferences.isHGVMode,
                avoidResidential: preferences.avoidResidential,
                avoidCameras: preferences.avoidCameras,
                avoidHazmatRestricted: preferences.avoidHazmatRestricted,
                enforceTurnRadius: preferences.enforceTurnRadius,
                enforceCurveSpeed: preferences.enforceCurveSpeed,
                vehicle: preferences.vehicle,
                algorithm: preferences.algorithm,
                requestSegmentSpeedLimits: false
            )
        )
    }
}

/// A turn maneuver from an external routing engine.
public struct ExternalManeuver: Sendable, Codable {
    public let instruction: String
    public let distanceMeters: Double
    public let durationSeconds: TimeInterval
    /// OpenRouteService step type code, when available.
    public let stepType: Int?
    /// Optional explicit speed limit from routing payload (native unit resolved at ingest).
    public let speedLimitKmh: Double?

    /// Creates an external maneuver.
    public init(
        instruction: String,
        distanceMeters: Double,
        durationSeconds: TimeInterval,
        stepType: Int? = nil,
        speedLimitKmh: Double? = nil
    ) {
        self.instruction = instruction
        self.distanceMeters = distanceMeters
        self.durationSeconds = durationSeconds
        self.stepType = stepType
        self.speedLimitKmh = speedLimitKmh
    }
}

/// Response from an external routing engine.
public struct ExternalRouteResponse: Sendable, Codable {
    public let encodedPolyline: String?
    public let polylinePrecision: Int
    public let coordinates: [Coordinate]
    public let distanceMeters: Double
    public let durationSeconds: TimeInterval
    public let maneuvers: [ExternalManeuver]
    /// Geometry-index-aligned speed limit metadata when requested from the routing engine.
    public let speedLimitSource: SegmentSpeedLimitSource?

    /// Creates an external route response with decoded geometry.
    public init(
        encodedPolyline: String? = nil,
        polylinePrecision: Int = 6,
        coordinates: [Coordinate],
        distanceMeters: Double,
        durationSeconds: TimeInterval,
        maneuvers: [ExternalManeuver] = [],
        speedLimitSource: SegmentSpeedLimitSource? = nil
    ) {
        self.encodedPolyline = encodedPolyline
        self.polylinePrecision = polylinePrecision
        self.coordinates = coordinates
        self.distanceMeters = distanceMeters
        self.durationSeconds = durationSeconds
        self.maneuvers = maneuvers
        self.speedLimitSource = speedLimitSource
    }
}

/// Protocol for external OpenRouteService/OSRM routing backends.
public protocol ExternalRoutingClient: Sendable {
    /// Calculates a route using an external engine.
    func route(request: ExternalRouteRequest) async throws -> ExternalRouteResponse
}

/// Stub client until a routing server URL is configured.
public struct StubExternalRoutingClient: ExternalRoutingClient {
    public init() {}

    public func route(request: ExternalRouteRequest) async throws -> ExternalRouteResponse {
        throw ExternalRoutingError.notConfigured
    }
}

/// Errors from external routing integration.
public enum ExternalRoutingError: Error, Sendable, LocalizedError {
    case notConfigured
    case invalidConfiguration
    case noRoute(reason: String)
    case vehicleDimensionBlocked(reason: String)
    case serverError(status: Int, body: String)

    /// User-facing message for HGV routing failures.
    public static let hgvNoRouteMessage =
        "No legal HGV route found matching your vehicle profile dimensions."

    /// User-facing message when vehicle dimensions exceed corridor physical limits.
    public static let vehicleDimensionBlockedMessage =
        "Route Blocked: Vehicle dimensions exceed physical limits on this corridor."

    public var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "External routing is not configured. Add your HeiGIT API key in Settings."
        case .invalidConfiguration:
            return "Routing configuration is invalid. Check your HeiGIT API key in Settings."
        case .noRoute:
            return Self.hgvNoRouteMessage
        case .vehicleDimensionBlocked:
            return Self.vehicleDimensionBlockedMessage
        case .serverError(let status, let body):
            if let message = ORSErrorParser.userFacingMessage(status: status, body: body) {
                return message
            }
            let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                return "Routing server error (HTTP \(status))."
            }
            let preview = trimmed.count > 160 ? String(trimmed.prefix(160)) + "…" : trimmed
            return "Routing server error (HTTP \(status)): \(preview)"
        }
    }

    /// Detailed server reason when available (for logging or secondary UI copy).
    public var serverReason: String? {
        switch self {
        case .noRoute(let reason):
            return reason
        case .vehicleDimensionBlocked(let reason):
            return reason
        case .serverError(_, let body):
            let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        case .notConfigured, .invalidConfiguration:
            return nil
        }
    }
}
