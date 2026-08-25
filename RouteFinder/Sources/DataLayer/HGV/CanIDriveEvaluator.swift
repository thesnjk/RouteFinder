import Contracts
import Foundation

/// Evaluates an advisory “Can I drive now?” answer from an imported card or the HOS clock.
///
/// Prefer a fresh imported ``TachoCardSummary`` (< 24 h). Otherwise use
/// ``HosClockSnapshot`` remainings. Always appends the legal tachograph disclaimer.
public enum CanIDriveEvaluator: Sendable {
    /// Maximum age for an imported card summary before the advisory clock is preferred.
    public static let importedCardFreshnessLimit: TimeInterval = 24 * 3600

    /// Evaluates drive eligibility from optional import + clock snapshot.
    public static func evaluate(
        imported: TachoCardSummary?,
        clockSnapshot: HosClockSnapshot,
        now: Date = Date()
    ) -> CanIDriveStatus {
        let usesImported: Bool
        let continuous: TimeInterval
        let daily: TimeInterval
        let sourceLabel: String

        if let imported,
           now.timeIntervalSince(imported.importedAt) < importedCardFreshnessLimit {
            usesImported = true
            continuous = imported.remainingContinuousDriveSeconds
            daily = imported.remainingDailyDriveSeconds
            sourceLabel = "imported card (\(imported.sourceFileName))"
        } else {
            usesImported = false
            continuous = clockSnapshot.remainingContinuousDriveSeconds
            daily = clockSnapshot.remainingDailyDriveSeconds
            sourceLabel = "advisory EU 561 clock"
        }

        let canDrive = continuous > 0 && daily > 0
        let budgetReason: String
        if canDrive {
            budgetReason =
                "Yes — remaining continuous \(format(continuous)), daily \(format(daily)) from \(sourceLabel)."
        } else if continuous <= 0 {
            budgetReason =
                "No — continuous drive remaining is exhausted (\(sourceLabel)). Take a mandatory break."
        } else {
            budgetReason =
                "No — daily drive remaining is exhausted (\(sourceLabel)). End the driving day."
        }

        let reason = "\(budgetReason) \(HosRestInsertionResult.legalDisclaimer)"
        return CanIDriveStatus(
            canDrive: canDrive,
            reason: reason,
            remainingContinuousDriveSeconds: continuous,
            usesImportedCard: usesImported
        )
    }

    private static func format(_ seconds: TimeInterval) -> String {
        let totalMinutes = max(0, Int((seconds / 60).rounded()))
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }
}
