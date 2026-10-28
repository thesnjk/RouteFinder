import Foundation

/// Summary of remaining drive budgets imported from a driver card export.
public struct TachoCardSummary: Sendable, Hashable, Codable, Equatable {
    /// Remaining continuous driving seconds before a mandatory break.
    public let remainingContinuousDriveSeconds: TimeInterval
    /// Remaining daily driving seconds.
    public let remainingDailyDriveSeconds: TimeInterval
    /// Remaining weekly driving seconds.
    public let remainingWeeklyDriveSeconds: TimeInterval
    /// Driver card number when present in the export.
    public let cardNumber: String?
    /// Wall-clock moment the file was imported.
    public let importedAt: Date
    /// Original file name used for the import.
    public let sourceFileName: String

    /// Creates a tachograph card summary.
    public init(
        remainingContinuousDriveSeconds: TimeInterval,
        remainingDailyDriveSeconds: TimeInterval,
        remainingWeeklyDriveSeconds: TimeInterval,
        cardNumber: String? = nil,
        importedAt: Date = Date(),
        sourceFileName: String
    ) {
        self.remainingContinuousDriveSeconds = remainingContinuousDriveSeconds
        self.remainingDailyDriveSeconds = remainingDailyDriveSeconds
        self.remainingWeeklyDriveSeconds = remainingWeeklyDriveSeconds
        self.cardNumber = cardNumber
        self.importedAt = importedAt
        self.sourceFileName = sourceFileName
    }
}

/// Advisory answer to “Can I drive now?” for planning only.
public struct CanIDriveStatus: Sendable, Hashable, Codable, Equatable {
    /// True when remaining continuous and daily drive budgets are both positive.
    public let canDrive: Bool
    /// Human-readable reason including the legal disclaimer.
    public let reason: String
    /// Remaining continuous driving seconds used for the decision.
    public let remainingContinuousDriveSeconds: TimeInterval
    /// True when the decision used an imported card summary rather than the advisory clock.
    public let usesImportedCard: Bool
    /// True when the decision used a partner webhook advisory (not legal VU).
    public let usesPartnerAdvisory: Bool

    /// Creates a can-I-drive status.
    public init(
        canDrive: Bool,
        reason: String,
        remainingContinuousDriveSeconds: TimeInterval,
        usesImportedCard: Bool,
        usesPartnerAdvisory: Bool = false
    ) {
        self.canDrive = canDrive
        self.reason = reason
        self.remainingContinuousDriveSeconds = remainingContinuousDriveSeconds
        self.usesImportedCard = usesImportedCard
        self.usesPartnerAdvisory = usesPartnerAdvisory
    }
}

/// Partner remaining-drive advisory from a webhook (planning aid — **not** a legal VU record).
public struct PartnerTachoAdvisory: Sendable, Hashable, Codable, Equatable {
    public let remainingContinuousDriveSeconds: TimeInterval
    public let remainingDailyDriveSeconds: TimeInterval
    public let remainingWeeklyDriveSeconds: TimeInterval?
    public let recordedAt: Date
    public let provider: String?
    public let vehicleLabel: String?

    public init(
        remainingContinuousDriveSeconds: TimeInterval,
        remainingDailyDriveSeconds: TimeInterval,
        remainingWeeklyDriveSeconds: TimeInterval? = nil,
        recordedAt: Date = Date(),
        provider: String? = nil,
        vehicleLabel: String? = nil
    ) {
        self.remainingContinuousDriveSeconds = remainingContinuousDriveSeconds
        self.remainingDailyDriveSeconds = remainingDailyDriveSeconds
        self.remainingWeeklyDriveSeconds = remainingWeeklyDriveSeconds
        self.recordedAt = recordedAt
        self.provider = provider
        self.vehicleLabel = vehicleLabel
    }

    /// Maps to ``TachoCardSummary`` for Can-I-drive evaluation.
    public func asTachoCardSummary() -> TachoCardSummary {
        let label = (provider?.isEmpty == false ? provider! : "partner")
        return TachoCardSummary(
            remainingContinuousDriveSeconds: remainingContinuousDriveSeconds,
            remainingDailyDriveSeconds: remainingDailyDriveSeconds,
            remainingWeeklyDriveSeconds: remainingWeeklyDriveSeconds ?? 0,
            cardNumber: vehicleLabel,
            importedAt: recordedAt,
            sourceFileName: "partner-webhook (\(label))"
        )
    }
}

/// Fleet webhook body for partner remaining-drive ingest.
public struct PartnerTachoIngestRequest: Sendable, Hashable, Codable, Equatable {
    public let remainingContinuousDriveSeconds: TimeInterval
    public let remainingDailyDriveSeconds: TimeInterval
    public let remainingWeeklyDriveSeconds: TimeInterval?
    public let recordedAt: Date?
    public let provider: String?
    public let vehicleLabel: String?

    public init(
        remainingContinuousDriveSeconds: TimeInterval,
        remainingDailyDriveSeconds: TimeInterval,
        remainingWeeklyDriveSeconds: TimeInterval? = nil,
        recordedAt: Date? = nil,
        provider: String? = nil,
        vehicleLabel: String? = nil
    ) {
        self.remainingContinuousDriveSeconds = remainingContinuousDriveSeconds
        self.remainingDailyDriveSeconds = remainingDailyDriveSeconds
        self.remainingWeeklyDriveSeconds = remainingWeeklyDriveSeconds
        self.recordedAt = recordedAt
        self.provider = provider
        self.vehicleLabel = vehicleLabel
    }
}

/// Imports driver-card DDD / JSON exports into an advisory remaining-time summary.
public protocol TachoCardImportPort: Sendable {
    /// Parses driver-card payload bytes into a remaining-time summary.
    func importDriverCard(data: Data) async throws -> TachoCardSummary
}

/// Remote partner tachograph status (VDO / Stoneridge / Samsara) — stub for later integration.
public protocol PartnerTachoPort: Sendable {
    /// Fetches remote remaining-time status from a configured partner.
    func fetchRemoteStatus() async throws -> TachoCardSummary
}
