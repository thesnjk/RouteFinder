import Foundation

/// A highway layby / rest pull-off projected onto the active route.
public struct LaybyStop: Sendable, Hashable, Codable, Equatable, Identifiable {
    public let id: String
    public let coordinate: Coordinate
    public let label: String
    public let arcLengthAlongRouteMeters: Double?
    public let distanceFromRouteMeters: Double?

    /// Creates a layby stop.
    public init(
        id: String,
        coordinate: Coordinate,
        label: String,
        arcLengthAlongRouteMeters: Double? = nil,
        distanceFromRouteMeters: Double? = nil
    ) {
        self.id = id
        self.coordinate = coordinate
        self.label = label
        self.arcLengthAlongRouteMeters = arcLengthAlongRouteMeters
        self.distanceFromRouteMeters = distanceFromRouteMeters
    }
}

/// Hour-of-day occupancy prior for a layby (heuristic — not live sensor data).
public enum LaybyOccupancyPrior: String, Sendable, Hashable, Codable, CaseIterable {
    case low
    case moderate
    case high

    /// Driver-facing label for HUD copy.
    public var displayLabel: String {
        switch self {
        case .low: return "low"
        case .moderate: return "moderate"
        case .high: return "high"
        }
    }
}

/// Signals that contributed to a layby prediction.
public enum LaybyReasonCode: String, Sendable, Hashable, Codable, CaseIterable {
    case hosDeadline
    case companyWindow
    case physicsStress
    case occupancy
    case trafficInflation
    case geometryFallback
}

/// Upcoming layby advisory for the driver HUD.
public struct LaybyAdvisory: Sendable, Hashable, Codable, Equatable {
    public let stop: LaybyStop
    public let distanceRemainingMeters: Double
    public let estimatedArrivalSeconds: TimeInterval?
    /// Model confidence from 0 (guess) to 1 (strong fusion).
    public let confidence: Double
    /// Heuristic occupancy prior at predicted arrival.
    public let occupancyPrior: LaybyOccupancyPrior
    /// When a company break window opens, if applicable.
    public let breakWindowOpensAt: Date?
    /// Factors that influenced this recommendation.
    public let reasonCodes: [LaybyReasonCode]
    /// True when HOS and/or company policy contributed (planning aid — not legal tacho).
    public let isAdvisory: Bool
    /// Timestamp of the newest on-device occupancy tap for this stop, if any.
    public let lastOccupancyReportAt: Date?
    /// Kind of the newest occupancy tap (full / spaces).
    public let lastOccupancyKind: LaybyOccupancyReport.Kind?

    /// Creates a layby advisory.
    public init(
        stop: LaybyStop,
        distanceRemainingMeters: Double,
        estimatedArrivalSeconds: TimeInterval? = nil,
        confidence: Double = 0.5,
        occupancyPrior: LaybyOccupancyPrior = .moderate,
        breakWindowOpensAt: Date? = nil,
        reasonCodes: [LaybyReasonCode] = [],
        isAdvisory: Bool = false,
        lastOccupancyReportAt: Date? = nil,
        lastOccupancyKind: LaybyOccupancyReport.Kind? = nil
    ) {
        self.stop = stop
        self.distanceRemainingMeters = distanceRemainingMeters
        self.estimatedArrivalSeconds = estimatedArrivalSeconds
        self.confidence = min(1, max(0, confidence))
        self.occupancyPrior = occupancyPrior
        self.breakWindowOpensAt = breakWindowOpensAt
        self.reasonCodes = reasonCodes
        self.isAdvisory = isAdvisory
        self.lastOccupancyReportAt = lastOccupancyReportAt
        self.lastOccupancyKind = lastOccupancyKind
    }
}

/// Inputs for fused layby prediction (on-device ranker).
public struct LaybyPredictionInput: Sendable, Hashable, Equatable {
    public let candidates: [LaybyStop]
    public let skippedIds: Set<String>
    public let currentArcLengthMeters: Double
    public let speedMps: Double
    public let pathDurationsSeconds: [TimeInterval]
    public let pathArcLengthsMeters: [Double]?
    public let remainingContinuousDriveSeconds: TimeInterval?
    public let remainingDailyDriveSeconds: TimeInterval?
    public let companyBreaks: [CompanyBreakAllocation]
    public let kineticStress: [SegmentKineticStress]?
    public let trafficInflationFactor: Double?
    public let now: Date
    /// On-device crowd occupancy reports that bias layby ranking.
    public let crowdReports: [CrowdReport]

    /// Creates layby prediction inputs.
    public init(
        candidates: [LaybyStop],
        skippedIds: Set<String> = [],
        currentArcLengthMeters: Double,
        speedMps: Double,
        pathDurationsSeconds: [TimeInterval] = [],
        pathArcLengthsMeters: [Double]? = nil,
        remainingContinuousDriveSeconds: TimeInterval? = nil,
        remainingDailyDriveSeconds: TimeInterval? = nil,
        companyBreaks: [CompanyBreakAllocation] = [],
        kineticStress: [SegmentKineticStress]? = nil,
        trafficInflationFactor: Double? = nil,
        now: Date = Date(),
        crowdReports: [CrowdReport] = []
    ) {
        self.candidates = candidates
        self.skippedIds = skippedIds
        self.currentArcLengthMeters = currentArcLengthMeters
        self.speedMps = speedMps
        self.pathDurationsSeconds = pathDurationsSeconds
        self.pathArcLengthsMeters = pathArcLengthsMeters
        self.remainingContinuousDriveSeconds = remainingContinuousDriveSeconds
        self.remainingDailyDriveSeconds = remainingDailyDriveSeconds
        self.companyBreaks = companyBreaks
        self.kineticStress = kineticStress
        self.trafficInflationFactor = trafficInflationFactor
        self.now = now
        self.crowdReports = crowdReports
    }
}

/// Ranked layby prediction output.
public struct LaybyPredictionResult: Sendable, Hashable, Codable, Equatable {
    public let ranked: [LaybyAdvisory]
    public let primary: LaybyAdvisory?

    /// Creates a prediction result.
    public init(ranked: [LaybyAdvisory], primary: LaybyAdvisory? = nil) {
        self.ranked = ranked
        self.primary = primary ?? ranked.first
    }
}
