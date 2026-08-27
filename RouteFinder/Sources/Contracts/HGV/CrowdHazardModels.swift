import Foundation

/// Crowd / sensor hazard event kinds reported by drivers.
public enum HazardEventType: String, Sendable, Hashable, Codable, CaseIterable {
    case closure
    case traffic
    case camera
    case weather
    case crowdReport
    /// Driver reported the recommended layby as full.
    case laybyFull
    /// Driver reported the recommended layby still has spaces.
    case laybySpaces
    case other
}

/// Severity of a hazard event for map / voice promotion.
public enum HazardSeverity: String, Sendable, Hashable, Codable, CaseIterable {
    case low
    case moderate
    case high
}

/// A spatially scoped hazard event on the living map layer.
public struct HazardEvent: Sendable, Hashable, Codable, Equatable, Identifiable {
    public let id: String
    public let latitude: Double
    public let longitude: Double
    public let radiusMeters: Double
    public let type: HazardEventType
    public let severity: HazardSeverity
    public let validFrom: Date
    public let validTo: Date
    public let source: String

    /// Creates a hazard event.
    public init(
        id: String = UUID().uuidString,
        latitude: Double,
        longitude: Double,
        radiusMeters: Double,
        type: HazardEventType,
        severity: HazardSeverity,
        validFrom: Date,
        validTo: Date,
        source: String
    ) {
        self.id = id
        self.latitude = latitude
        self.longitude = longitude
        self.radiusMeters = radiusMeters
        self.type = type
        self.severity = severity
        self.validFrom = validFrom
        self.validTo = validTo
        self.source = source
    }
}

/// A crowd report submitted by a driver near a location.
public struct CrowdReport: Sendable, Hashable, Codable, Equatable, Identifiable {
    public let id: String
    public let latitude: Double
    public let longitude: Double
    public let type: HazardEventType
    public let reporterId: String
    public let createdAt: Date
    public let note: String?

    /// Creates a crowd report.
    public init(
        id: String = UUID().uuidString,
        latitude: Double,
        longitude: Double,
        type: HazardEventType,
        reporterId: String,
        createdAt: Date = Date(),
        note: String? = nil
    ) {
        self.id = id
        self.latitude = latitude
        self.longitude = longitude
        self.type = type
        self.reporterId = reporterId
        self.createdAt = createdAt
        self.note = note
    }
}

/// Inputs used to score crowd-report confidence.
public struct CrowdConfidenceInputs: Sendable, Hashable, Codable, Equatable {
    public let uniqueVehiclesNearby: Int
    public let ageSeconds: TimeInterval
    public let reporterReputation: Double
    public let corroborationCount: Int

    /// Creates crowd confidence inputs.
    public init(
        uniqueVehiclesNearby: Int,
        ageSeconds: TimeInterval,
        reporterReputation: Double,
        corroborationCount: Int
    ) {
        self.uniqueVehiclesNearby = uniqueVehiclesNearby
        self.ageSeconds = ageSeconds
        self.reporterReputation = reporterReputation
        self.corroborationCount = corroborationCount
    }
}

/// Prompt asking the reporter whether a hazard is still present.
public struct CrowdReportStillTherePrompt: Sendable, Hashable, Codable, Equatable, Identifiable {
    public let id: String
    public let reportType: HazardEventType
    public let message: String

    /// Creates a still-there prompt.
    public init(id: String, reportType: HazardEventType, message: String) {
        self.id = id
        self.reportType = reportType
        self.message = message
    }
}

/// Scores crowd reports and optionally promotes them to map hazards.
public enum CrowdEventBus: Sendable {
    /// Confidence score in `[0, 1]` from corroboration / age / reputation.
    public static func confidenceScore(inputs: CrowdConfidenceInputs) -> Double {
        let nearby = min(1.0, Double(inputs.uniqueVehiclesNearby) / 5.0)
        let corroboration = min(1.0, Double(inputs.corroborationCount) / 3.0)
        let ageDecay = max(0, 1.0 - inputs.ageSeconds / (6 * 3600))
        let reputation = min(1.0, max(0, inputs.reporterReputation))
        let raw = 0.3 * nearby + 0.3 * corroboration + 0.2 * ageDecay + 0.2 * reputation
        return min(1, max(0, raw))
    }

    /// Promotes a report to a hazard when confidence clears the threshold.
    public static func promoteIfConfident(
        report: CrowdReport,
        inputs: CrowdConfidenceInputs,
        severity: HazardSeverity,
        threshold: Double = 0.55,
        radiusMeters: Double = 90,
        validForSeconds: TimeInterval = 45 * 60
    ) -> HazardEvent? {
        let score = confidenceScore(inputs: inputs)
        guard score >= threshold else { return nil }
        let now = Date()
        return HazardEvent(
            id: "crowd-\(report.id)",
            latitude: report.latitude,
            longitude: report.longitude,
            radiusMeters: radiusMeters,
            type: report.type,
            severity: severity,
            validFrom: now,
            validTo: now.addingTimeInterval(validForSeconds),
            source: "crowd:\(report.reporterId)"
        )
    }
}
