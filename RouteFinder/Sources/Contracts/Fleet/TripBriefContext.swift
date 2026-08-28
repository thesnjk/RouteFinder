import Foundation

/// A labeled stop included in a shareable trip brief.
public struct TripBriefStop: Sendable, Equatable {
    /// Display label for the stop.
    public let label: String
    /// Optional role string (e.g. origin, via, destination).
    public let role: String?
    /// Optional map coordinate for PDF stop pin overlays.
    public let coordinate: Coordinate?

    /// Creates a trip brief stop row.
    public init(label: String, role: String? = nil, coordinate: Coordinate? = nil) {
        self.label = label
        self.role = role
        self.coordinate = coordinate
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
    /// Route polyline coordinates for PDF map snapshot rendering.
    public var routeCoordinates: [Coordinate]
    /// Latest completed walkaround with defects, when dispatch should be warned.
    public var latestInspectionSummary: TripBriefInspectionSummary?

    /// Creates a trip brief context.
    public init(
        predictiveReport: PredictiveTelemetryReport? = nil,
        hosForecast: HosRestInsertionResult? = nil,
        laybyAdvisory: LaybyAdvisory? = nil,
        stops: [TripBriefStop] = [],
        companyBreaks: [CompanyBreakAllocation] = [],
        physicsETASeconds: TimeInterval? = nil,
        vehicleLabel: String? = nil,
        tripStatus: String? = nil,
        routeCoordinates: [Coordinate] = [],
        latestInspectionSummary: TripBriefInspectionSummary? = nil
    ) {
        self.predictiveReport = predictiveReport
        self.hosForecast = hosForecast
        self.laybyAdvisory = laybyAdvisory
        self.stops = stops
        self.companyBreaks = companyBreaks
        self.physicsETASeconds = physicsETASeconds
        self.vehicleLabel = vehicleLabel
        self.tripStatus = tripStatus
        self.routeCoordinates = routeCoordinates
        self.latestInspectionSummary = latestInspectionSummary
    }

    /// Builds brief context from a fleet trip snapshot visible to dispatch.
    public static func from(
        fleetTrip: FleetTrip,
        vehicleLabel: String? = nil,
        previewCoordinates: [Coordinate] = []
    ) -> TripBriefContext {
        let routeCoordinates: [Coordinate]
        if previewCoordinates.count >= 2 {
            routeCoordinates = previewCoordinates
        } else {
            routeCoordinates = DispatchRoutePreviewBuilder.straightLineCoordinates(from: fleetTrip.stops)
        }
        return TripBriefContext(
            predictiveReport: fleetTrip.predictiveReport,
            laybyAdvisory: fleetTrip.predictedLayby,
            stops: fleetTrip.stops
                .sorted { $0.sequence < $1.sequence }
                .map {
                    TripBriefStop(
                        label: $0.label,
                        role: $0.role.rawValue,
                        coordinate: Coordinate(latitude: $0.latitude, longitude: $0.longitude)
                    )
                },
            companyBreaks: fleetTrip.companyBreaks,
            physicsETASeconds: fleetTrip.physicsETASeconds,
            vehicleLabel: vehicleLabel,
            tripStatus: fleetTrip.status.rawValue.capitalized,
            routeCoordinates: routeCoordinates,
            latestInspectionSummary: fleetTrip.latestInspectionSummary
        )
    }
}
