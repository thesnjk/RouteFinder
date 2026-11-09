import type { PartnerTachoAdvisory } from './fleet/types'

/** EU weekly planning allowance when partner omits weekly (mirrors Swift asTachoCardSummary). */
export const DEFAULT_WEEKLY_DRIVE_SECONDS = 56 * 3600

/** Same legal line as HosRestInsertionResult.legalDisclaimer on iOS/Mac. */
export const LEGAL_DISCLAIMER =
  'The digital tachograph is the legal record. This clock is a planning aid only.'

export interface CanIDriveDeskResult {
  canDrive: boolean
  reason: string
  weeklySeconds: number
}

function formatBudget(seconds: number): string {
  const totalMinutes = Math.max(0, Math.round(seconds / 60))
  const hours = Math.floor(totalMinutes / 60)
  const minutes = totalMinutes % 60
  if (hours > 0 && minutes > 0) return `${hours}h ${minutes}m`
  if (hours > 0) return `${hours}h`
  return `${minutes}m`
}

/**
 * Evaluates partner advisory for the desk Can-I-drive card.
 * Gates on continuous, daily, and weekly remaining (omitted weekly → 56h).
 */
export function evaluatePartnerAdvisory(
  advisory: Pick<
    PartnerTachoAdvisory,
    | 'remainingContinuousDriveSeconds'
    | 'remainingDailyDriveSeconds'
    | 'remainingWeeklyDriveSeconds'
    | 'provider'
    | 'vehicleLabel'
  >,
): CanIDriveDeskResult {
  const continuous = advisory.remainingContinuousDriveSeconds
  const daily = advisory.remainingDailyDriveSeconds
  const weekly =
    advisory.remainingWeeklyDriveSeconds == null
      ? DEFAULT_WEEKLY_DRIVE_SECONDS
      : advisory.remainingWeeklyDriveSeconds
  const provider =
    advisory.provider && advisory.provider.trim().length > 0 ? advisory.provider.trim() : 'partner'
  const sourceLabel = `partner advisory (${provider})`

  const canDrive = continuous > 0 && daily > 0 && weekly > 0

  let budgetReason: string
  if (canDrive) {
    budgetReason = `Yes — remaining continuous ${formatBudget(continuous)}, daily ${formatBudget(daily)}, weekly ${formatBudget(weekly)} from ${sourceLabel}.`
  } else if (continuous <= 0) {
    budgetReason = `No — continuous drive remaining is exhausted (${sourceLabel}). Take a mandatory break.`
  } else if (daily <= 0) {
    budgetReason = `No — daily drive remaining is exhausted (${sourceLabel}). End the driving day.`
  } else {
    budgetReason = `No — weekly drive remaining is exhausted (${sourceLabel}). End the driving week.`
  }

  return {
    canDrive,
    reason: `${budgetReason} ${LEGAL_DISCLAIMER}`,
    weeklySeconds: weekly,
  }
}
