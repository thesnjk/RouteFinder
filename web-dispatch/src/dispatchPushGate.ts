/**
 * Pure desk push eligibility (parity with Mac DispatchPushGate).
 * Push requires remote Connected health — not Local disk / Auth failed / Offline.
 */

export function canPushTrip(options: {
  hasVehicle: boolean
  hasResolvedStops: boolean
  healthOk: boolean
}): boolean {
  const { hasVehicle, hasResolvedStops, healthOk } = options
  return hasVehicle && hasResolvedStops && healthOk
}

/** Draft ready but health pill is not Connected. */
export function isPushBlockedByFleetHealth(options: {
  hasVehicle: boolean
  hasResolvedStops: boolean
  healthOk: boolean
}): boolean {
  const { hasVehicle, hasResolvedStops, healthOk } = options
  return hasVehicle && hasResolvedStops && !healthOk
}
