import Contracts
import Foundation

/// Evaluates an advisory “Can I drive now?” answer from partner webhook, imported card, or HOS clock.
///
/// Priority when fresh (< 24 h): partner advisory → imported card → ``HosClockSnapshot``.
/// Always appends the legal tachograph disclaimer.
public enum CanIDriveEvaluator: Sendable {
    /// Maximum age for partner / imported summaries before the advisory clock is preferred.
    public static let importedCardFreshnessLimit: TimeInterval = 24 * 3600

    /// Evaluates drive eligibility from optional partner + import + clock snapshot.
    public static func evaluate(
        partner: TachoCardSummary? = nil,
        imported: TachoCardSummary?,
        clockSnapshot: HosClockSnapshot,
        now: Date = Date()
    ) -> CanIDriveStatus {
        let continuous: TimeInterval
        let daily: TimeInterval
        let sourceLabel: String
        let usesImported: Bool
        let usesPartner: Bool

        if let partner,
           now.timeIntervalSince(partner.importedAt) < importedCardFreshnessLimit {
            continuous = partner.remainingContinuousDriveSeconds
            daily = partner.remainingDailyDriveSeconds
            sourceLabel = "partner advisory (\(partner.sourceFileName))"
            usesImported = false
            usesPartner = true
        } else if let imported,
                  now.timeIntervalSince(imported.importedAt) < importedCardFreshnessLimit {
            continuous = imported.remainingContinuousDriveSeconds
            daily = imported.remainingDailyDriveSeconds
            sourceLabel = "imported card (\(imported.sourceFileName))"
            usesImported = true
            usesPartner = false
        } else {
            continuous = clockSnapshot.remainingContinuousDriveSeconds
            daily = clockSnapshot.remainingDailyDriveSeconds
            sourceLabel = "advisory EU 561 clock"
            usesImported = false
            usesPartner = false
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
            usesImportedCard: usesImported,
            usesPartnerAdvisory: usesPartner
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
