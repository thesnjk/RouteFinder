import Foundation

/// Duty mode for the advisory hours-of-service clock.
public enum HosDutyMode: String, Sendable, Hashable, Codable, CaseIterable {
    case offDuty
    case driving
    case otherWork
    case availability
    case breakRest

    /// Short label for HUD / CarPlay.
    public var displayName: String {
        switch self {
        case .offDuty: return "Off duty"
        case .driving: return "Driving"
        case .otherWork: return "Other work"
        case .availability: return "POA"
        case .breakRest: return "Break / rest"
        }
    }
}

/// Event that transitions the advisory HOS clock.
public struct HosDutyEvent: Sendable, Hashable, Codable, Equatable {
    public let mode: HosDutyMode
    public let at: Date
    public let note: String?

    /// Creates a duty transition event.
    public init(mode: HosDutyMode, at: Date = Date(), note: String? = nil) {
        self.mode = mode
        self.at = at
        self.note = note
    }
}

/// Suggested rest insertion along a planned path.
public struct HosRestInsertion: Sendable, Hashable, Codable, Equatable, Identifiable {
    public let id: String
    /// Index into the path-duration samples after which rest should begin.
    public let afterSegmentIndex: Int
    /// Arc length along the route where rest should occur, when known.
    public let arcLengthMeters: Double?
    /// Preferred truck POI identifier, when resolved.
    public let poiId: String?
    /// Required rest duration in seconds.
    public let restDurationSeconds: TimeInterval
    /// Driver-facing reason (e.g. "45 min break before 4.5 h limit").
    public let reason: String
    /// True when physics stress voted to rest upstream of a grade.
    public let physicsPreferred: Bool

    /// Creates a rest insertion suggestion.
    public init(
        id: String = UUID().uuidString,
        afterSegmentIndex: Int,
        arcLengthMeters: Double? = nil,
        poiId: String? = nil,
        restDurationSeconds: TimeInterval,
        reason: String,
        physicsPreferred: Bool = false
    ) {
        self.id = id
        self.afterSegmentIndex = afterSegmentIndex
        self.arcLengthMeters = arcLengthMeters
        self.poiId = poiId
        self.restDurationSeconds = restDurationSeconds
        self.reason = reason
        self.physicsPreferred = physicsPreferred
    }
}

/// Forecast result from the HOS clock for a planned path.
public struct HosRestInsertionResult: Sendable, Hashable, Codable, Equatable {
    /// Remaining continuous driving seconds before a mandatory break.
    public let remainingContinuousDriveSeconds: TimeInterval
    /// Remaining daily driving seconds.
    public let remainingDailyDriveSeconds: TimeInterval
    /// Suggested rest insertions along the path (may be empty).
    public let insertions: [HosRestInsertion]
    /// Plain-language summary for the trip brief.
    public let summary: String

    /// Creates a forecast result.
    public init(
        remainingContinuousDriveSeconds: TimeInterval,
        remainingDailyDriveSeconds: TimeInterval,
        insertions: [HosRestInsertion],
        summary: String
    ) {
        self.remainingContinuousDriveSeconds = remainingContinuousDriveSeconds
        self.remainingDailyDriveSeconds = remainingDailyDriveSeconds
        self.insertions = insertions
        self.summary = summary
    }

    /// Legal disclaimer shown on every hours surface.
    public static let legalDisclaimer =
        "The digital tachograph is the legal record. This clock is a planning aid only."
}

/// Snapshot of advisory remaining times for HUD display.
public struct HosClockSnapshot: Sendable, Hashable, Codable, Equatable {
    public let mode: HosDutyMode
    public let remainingContinuousDriveSeconds: TimeInterval
    public let remainingDailyDriveSeconds: TimeInterval
    public let remainingWeeklyDriveSeconds: TimeInterval
    public let updatedAt: Date

    /// Creates a clock snapshot.
    public init(
        mode: HosDutyMode,
        remainingContinuousDriveSeconds: TimeInterval,
        remainingDailyDriveSeconds: TimeInterval,
        remainingWeeklyDriveSeconds: TimeInterval,
        updatedAt: Date = Date()
    ) {
        self.mode = mode
        self.remainingContinuousDriveSeconds = remainingContinuousDriveSeconds
        self.remainingDailyDriveSeconds = remainingDailyDriveSeconds
        self.remainingWeeklyDriveSeconds = remainingWeeklyDriveSeconds
        self.updatedAt = updatedAt
    }
}
