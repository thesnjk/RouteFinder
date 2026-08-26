import Foundation

/// A labeled stop included in a shareable trip brief.
public struct TripBriefStop: Sendable, Equatable {
    /// Display label for the stop.
    public let label: String
    /// Optional role string (e.g. origin, via, destination).
    public let role: String?

    /// Creates a trip brief stop row.
    public init(label: String, role: String? = nil) {
        self.label = label
        self.role = role
    }
}

/// Inputs for formatting a unified predictive trip brief.
public struct TripBriefContext: Sendable, Equatable {
    public var predictiveReport: PredictiveTelemetryReport?
    public var hosForecast: HosRestInsertionResult?
    public var laybyAdvisory: LaybyAdvisory?
    public var stops: [TripBriefStop]
    public var companyBreaks: [CompanyBreakAllocation]
    public var physicsETASeconds: TimeInterval?
    public var vehicleLabel: String?
    public var tripStatus: String?

    /// Creates a trip brief context.
    public init(
        predictiveReport: PredictiveTelemetryReport? = nil,
        hosForecast: HosRestInsertionResult? = nil,
        laybyAdvisory: LaybyAdvisory? = nil,
        stops: [TripBriefStop] = [],
        companyBreaks: [CompanyBreakAllocation] = [],
        physicsETASeconds: TimeInterval? = nil,
        vehicleLabel: String? = nil,
        tripStatus: String? = nil
    ) {
        self.predictiveReport = predictiveReport
        self.hosForecast = hosForecast
        self.laybyAdvisory = laybyAdvisory
        self.stops = stops
        self.companyBreaks = companyBreaks
        self.physicsETASeconds = physicsETASeconds
        self.vehicleLabel = vehicleLabel
        self.tripStatus = tripStatus
    }

    /// Builds brief context from a fleet trip snapshot visible to dispatch.
    public static func from(fleetTrip: FleetTrip, vehicleLabel: String? = nil) -> TripBriefContext {
        TripBriefContext(
            predictiveReport: fleetTrip.predictiveReport,
            laybyAdvisory: fleetTrip.predictedLayby,
            stops: fleetTrip.stops
                .sorted { $0.sequence < $1.sequence }
                .map { TripBriefStop(label: $0.label, role: $0.role.rawValue) },
            companyBreaks: fleetTrip.companyBreaks,
            physicsETASeconds: fleetTrip.physicsETASeconds,
            vehicleLabel: vehicleLabel,
            tripStatus: fleetTrip.status.rawValue.capitalized
        )
    }
}
