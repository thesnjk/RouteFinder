import Foundation

/// Kind of fused predictive risk along the active route.
public enum RouteRiskKind: String, Sendable, Hashable, Codable, CaseIterable {
    case kinetic
    case weather
    case traffic
    case roadworks
    case hazard
    case clearance
}

/// Severity for HUD / voice prioritization.
public enum RouteRiskSeverity: String, Sendable, Hashable, Codable, CaseIterable, Comparable {
    case info
    case caution
    case severe

    public static func < (lhs: RouteRiskSeverity, rhs: RouteRiskSeverity) -> Bool {
        lhs.rank < rhs.rank
    }

    private var rank: Int {
        switch self {
        case .info: 0
        case .caution: 1
        case .severe: 2
        }
    }
}

/// Unified risk advisory for map chrome and voice (predictive hazard / environmental safety).
public struct RouteRiskAdvisory: Sendable, Hashable, Codable, Equatable, Identifiable {
    public let id: String
    public var kind: RouteRiskKind
    public var severity: RouteRiskSeverity
    /// Distance remaining along the route spine in meters.
    public var distanceRemainingMeters: Double
    public var message: String
    public var spokenPrompt: String
    public var source: String

    /// Creates a route risk advisory.
    public init(
        id: String,
        kind: RouteRiskKind,
        severity: RouteRiskSeverity,
        distanceRemainingMeters: Double,
        message: String,
        spokenPrompt: String,
        source: String
    ) {
        self.id = id
        self.kind = kind
        self.severity = severity
        self.distanceRemainingMeters = distanceRemainingMeters
        self.message = message
        self.spokenPrompt = spokenPrompt
        self.source = source
    }
}

/// Formats and ranks fused route-risk advisories.
public enum RouteRiskFormatter: Sendable {
    /// Picks the highest-severity advisory still ahead within the horizon.
    public static func primaryAhead(
        advisories: [RouteRiskAdvisory],
        maxAheadMeters: Double = 8_000
    ) -> RouteRiskAdvisory? {
        advisories
            .filter { $0.distanceRemainingMeters > 0 && $0.distanceRemainingMeters <= maxAheadMeters }
            .max { lhs, rhs in
                if lhs.severity != rhs.severity { return lhs.severity < rhs.severity }
                return lhs.distanceRemainingMeters > rhs.distanceRemainingMeters
            }
    }

    /// Spoken prompt for a risk advisory.
    public static func spokenPrompt(for advisory: RouteRiskAdvisory) -> String {
        let trimmed = advisory.spokenPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? advisory.message : trimmed
    }
}

/// Inputs for the MVP predictive risk fuse (no new network).
public struct PredictiveRiskSnapshot: Sendable, Hashable, Equatable {
    public var kineticMessage: String?
    public var kineticDistanceMeters: Double?
    public var weatherMessage: String?
    public var weatherDistanceMeters: Double?
    public var hazard: HazardAheadAnnouncement?
    public var roadworksMessage: String?
    public var roadworksDistanceMeters: Double?
    public var trafficMessage: String?
    public var trafficDistanceMeters: Double?
    /// Late vs dispatch time window (``source`` ``timeWindow``).
    public var scheduleLateMessage: String?
    public var scheduleLateDistanceMeters: Double?
    /// Horizon forecast advisories from TomTom / OpenWeather (U8).
    public var forecastItems: [RouteRiskAdvisory]
    /// Corridor clearance advisories from Overpass (U9).
    public var clearanceItems: [RouteRiskAdvisory]

    /// Creates an empty snapshot.
    public init(
        kineticMessage: String? = nil,
        kineticDistanceMeters: Double? = nil,
        weatherMessage: String? = nil,
        weatherDistanceMeters: Double? = nil,
        hazard: HazardAheadAnnouncement? = nil,
        roadworksMessage: String? = nil,
        roadworksDistanceMeters: Double? = nil,
        trafficMessage: String? = nil,
        trafficDistanceMeters: Double? = nil,
        scheduleLateMessage: String? = nil,
        scheduleLateDistanceMeters: Double? = nil,
        forecastItems: [RouteRiskAdvisory] = [],
        clearanceItems: [RouteRiskAdvisory] = []
    ) {
        self.kineticMessage = kineticMessage
        self.kineticDistanceMeters = kineticDistanceMeters
        self.weatherMessage = weatherMessage
        self.weatherDistanceMeters = weatherDistanceMeters
        self.hazard = hazard
        self.roadworksMessage = roadworksMessage
        self.roadworksDistanceMeters = roadworksDistanceMeters
        self.trafficMessage = trafficMessage
        self.trafficDistanceMeters = trafficDistanceMeters
        self.scheduleLateMessage = scheduleLateMessage
        self.scheduleLateDistanceMeters = scheduleLateDistanceMeters
        self.forecastItems = forecastItems
        self.clearanceItems = clearanceItems
    }
}

/// Evaluates physics ETA against dispatch stop time windows.
public enum TimeWindowRiskEvaluator: Sendable {
    /// Slack before a late advisory fires (seconds).
    public static let lateSlackSeconds: TimeInterval = 15 * 60
    /// Horizon for "approaching window" info advisories (seconds).
    public static let approachHorizonSeconds: TimeInterval = 2 * 3_600

    /// Builds a single schedule advisory when projected arrival misses ``latestArrival``.
    public static func advisory(
        windows: [StopTimeWindow],
        stops: [FleetTripStop],
        physicsETASeconds: TimeInterval?,
        now: Date = Date()
    ) -> (message: String, distanceMeters: Double)? {
        guard let eta = physicsETASeconds, eta > 0 else { return nil }
        let projectedArrival = now.addingTimeInterval(eta)
        var worstLate: (message: String, lateBy: TimeInterval)?

        for window in windows {
            guard let latest = window.latestArrival else { continue }
            let lateBy = projectedArrival.timeIntervalSince(latest)
            guard lateBy > lateSlackSeconds else { continue }
            let label = stops.first(where: { $0.id == window.stopId })?.label ?? "stop"
            let minutesLate = Int((lateBy / 60).rounded())
            let message = "Projected late to \(label) by \(minutesLate) min (dispatch window)"
            if worstLate == nil || lateBy > (worstLate?.lateBy ?? 0) {
                worstLate = (message, lateBy)
            }
        }

        if let worst = worstLate {
            // Distance proxy: remaining journey (ETA as meters at ~60 km/h).
            let distance = max(500, eta * (60_000 / 3_600))
            return (worst.message, min(distance, 50_000))
        }

        // Approaching window within 2h with no late risk — info only for nearest latestArrival.
        var nearest: (message: String, until: TimeInterval)?
        for window in windows {
            guard let latest = window.latestArrival else { continue }
            let until = latest.timeIntervalSince(projectedArrival)
            guard until > 0, until <= approachHorizonSeconds else { continue }
            let label = stops.first(where: { $0.id == window.stopId })?.label ?? "stop"
            let minutes = Int((until / 60).rounded())
            let message = "Arrive \(label) within window (\(minutes) min margin)"
            if nearest == nil || until < (nearest?.until ?? .greatestFiniteMagnitude) {
                nearest = (message, until)
            }
        }
        // Approach advisories are optional HUD noise — only emit when late risk exists above.
        _ = nearest
        return nil
    }
}

/// Fuses existing kinetic / weather / hazard / roadworks / traffic signals into ``RouteRiskAdvisory`` values.
public enum PredictiveRiskEngine: Sendable {
    /// Builds advisories from a snapshot of already-computed signals (MVP — no ML).
    public static func fuse(snapshot: PredictiveRiskSnapshot) -> [RouteRiskAdvisory] {
        var items: [RouteRiskAdvisory] = []

        // Severe forecast first so primaryAhead prefers them when severity ties break on distance.
        items.append(contentsOf: snapshot.forecastItems.filter { $0.severity == .severe })

        if let message = snapshot.kineticMessage?.trimmingCharacters(in: .whitespacesAndNewlines), !message.isEmpty {
            let distance = snapshot.kineticDistanceMeters ?? 1_500
            items.append(
                RouteRiskAdvisory(
                    id: "kinetic-\(message.hashValue)",
                    kind: .kinetic,
                    severity: .caution,
                    distanceRemainingMeters: distance,
                    message: message,
                    spokenPrompt: message,
                    source: "kinetic"
                )
            )
        }

        if let message = snapshot.weatherMessage?.trimmingCharacters(in: .whitespacesAndNewlines), !message.isEmpty {
            let distance = snapshot.weatherDistanceMeters ?? 3_000
            items.append(
                RouteRiskAdvisory(
                    id: "weather-\(message.hashValue)",
                    kind: .weather,
                    severity: .caution,
                    distanceRemainingMeters: distance,
                    message: message,
                    spokenPrompt: message,
                    source: "weather"
                )
            )
        }

        if let hazard = snapshot.hazard {
            items.append(
                RouteRiskAdvisory(
                    id: "hazard-\(hazard.id)",
                    kind: .hazard,
                    severity: hazard.type == .closure ? .severe : .caution,
                    distanceRemainingMeters: hazard.distanceRemainingMeters,
                    message: hazard.message,
                    spokenPrompt: HazardAheadFormatter.spokenPrompt(for: hazard),
                    source: hazard.source
                )
            )
        }

        if let message = snapshot.roadworksMessage?.trimmingCharacters(in: .whitespacesAndNewlines), !message.isEmpty {
            let distance = snapshot.roadworksDistanceMeters ?? 2_000
            items.append(
                RouteRiskAdvisory(
                    id: "roadworks-\(message.hashValue)",
                    kind: .roadworks,
                    severity: .info,
                    distanceRemainingMeters: distance,
                    message: message,
                    spokenPrompt: message,
                    source: "roadworks"
                )
            )
        }

        if let message = snapshot.trafficMessage?.trimmingCharacters(in: .whitespacesAndNewlines), !message.isEmpty {
            let distance = snapshot.trafficDistanceMeters ?? 2_500
            items.append(
                RouteRiskAdvisory(
                    id: "traffic-\(message.hashValue)",
                    kind: .traffic,
                    severity: .caution,
                    distanceRemainingMeters: distance,
                    message: message,
                    spokenPrompt: message,
                    source: "traffic"
                )
            )
        }

        if let message = snapshot.scheduleLateMessage?.trimmingCharacters(in: .whitespacesAndNewlines), !message.isEmpty {
            let distance = snapshot.scheduleLateDistanceMeters ?? 5_000
            items.append(
                RouteRiskAdvisory(
                    id: "schedule-\(message.hashValue)",
                    kind: .traffic,
                    severity: .caution,
                    distanceRemainingMeters: distance,
                    message: message,
                    spokenPrompt: message,
                    source: "timeWindow"
                )
            )
        }

        items.append(contentsOf: snapshot.forecastItems.filter { $0.severity != .severe })
        items.append(contentsOf: snapshot.clearanceItems)

        return items
    }
}

/// Async provider of fused risk advisories along the active route (future forecast / clearance probes).
public protocol PredictiveRiskProviding: Sendable {
    /// Returns current fused advisories for the active navigation context.
    func advisories(for snapshot: PredictiveRiskSnapshot) async -> [RouteRiskAdvisory]
}

/// Default provider that only fuses existing signals.
public struct DefaultPredictiveRiskProvider: PredictiveRiskProviding {
    /// Creates the default provider.
    public init() {}

    public func advisories(for snapshot: PredictiveRiskSnapshot) async -> [RouteRiskAdvisory] {
        PredictiveRiskEngine.fuse(snapshot: snapshot)
    }
}
