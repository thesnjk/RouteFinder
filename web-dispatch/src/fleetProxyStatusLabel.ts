import type { FleetProxyStatus } from './fleet/types'

/** Fraction of daily cap at which the desk shows a near-cap warning (Mac parity). */
export const NEAR_CAP_FRACTION = 0.9

const NEAR_CAP_WARNING =
  'Near daily proxy cap — raise --route-daily-cap / --geocode-daily-cap or wait until tomorrow.'

/** Masks a bearer/API token for Connection panel display (never show full secret). */
export function maskApiKey(token: string): string {
  const trimmed = token.trim()
  if (!trimmed) return '(none)'
  if (trimmed.length <= 8) return '••••'
  return `${trimmed.slice(0, 4)}…${trimmed.slice(-4)}`
}

/** Authenticated depot line from proxy status org identity (Mac parity). */
export function authenticatedDepotLine(status: FleetProxyStatus): string | null {
  const name = status.orgName?.trim()
  if (!name) return null
  const id = status.orgId?.trim()
  if (id) return `Authenticated depot: ${name} (${id})`
  return `Authenticated depot: ${name}`
}

/** Remaining ORS route budget for today (never negative). */
export function routesRemaining(status: FleetProxyStatus): number {
  return Math.max(0, status.routeDailyCap - status.routesToday)
}

/** Remaining ORS geocode budget for today (never negative). */
export function geocodesRemaining(status: FleetProxyStatus): number {
  return Math.max(0, status.geocodeDailyCap - status.geocodeToday)
}

function isNearCap(used: number, cap: number): boolean {
  if (cap <= 0) return false
  return used >= cap * NEAR_CAP_FRACTION
}

/** True when routes used ≥ 90% of the daily cap. */
export function isNearRouteCap(status: FleetProxyStatus): boolean {
  return isNearCap(status.routesToday, status.routeDailyCap)
}

/** True when geocodes used ≥ 90% of the daily cap. */
export function isNearGeocodeCap(status: FleetProxyStatus): boolean {
  return isNearCap(status.geocodeToday, status.geocodeDailyCap)
}

/** True when ORS is on and either meter is near its daily cap. */
export function isNearAnyORSCap(status: FleetProxyStatus): boolean {
  return status.orsConfigured && (isNearRouteCap(status) || isNearGeocodeCap(status))
}

/**
 * ORS Connection-panel line with used/cap and remaining (Mac Fleet proxy parity).
 */
export function orsSummaryLine(status: FleetProxyStatus): string {
  if (!status.orsConfigured) {
    return 'ORS proxy: off (start server with --ors-key for address search and driver routing)'
  }
  return (
    `ORS proxy: on · ${status.routesToday}/${status.routeDailyCap} routes · ${routesRemaining(status)} left` +
    ` · ${status.geocodeToday}/${status.geocodeDailyCap} geocodes · ${geocodesRemaining(status)} left`
  )
}

/** Near-cap caption when either ORS meter is ≥ 90% used; otherwise null. */
export function nearCapWarning(status: FleetProxyStatus): string | null {
  if (!isNearAnyORSCap(status)) return null
  return NEAR_CAP_WARNING
}
