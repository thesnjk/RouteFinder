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

    /// Creates a can-I-drive status.
    public init(
        canDrive: Bool,
        reason: String,
        remainingContinuousDriveSeconds: TimeInterval,
        usesImportedCard: Bool
    ) {
        self.canDrive = canDrive
        self.reason = reason
        self.remainingContinuousDriveSeconds = remainingContinuousDriveSeconds
        self.usesImportedCard = usesImportedCard
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
