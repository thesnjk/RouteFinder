import type { LaybyOccupancyPrior, PredictedLayby } from './fleet/types'

/** CoPilot-style availability band inverted from occupancy prior. */
export type ParkingAvailabilityTier = 'ample' | 'limited' | 'full'

/** True when the trip carries a predicted layby with coordinates. */
export function hasPredictedLayby(
  trip: { predictedLayby?: PredictedLayby | null } | null | undefined,
): boolean {
  const layby = trip?.predictedLayby
  if (!layby?.stop?.coordinate) return false
  const { latitude, longitude } = layby.stop.coordinate
  return Number.isFinite(latitude) && Number.isFinite(longitude)
}

/** Invert occupancy prior → driver/desk availability tier (mirrors ParkingAvailabilityTier). */
export function parkingTierFromOccupancy(prior: LaybyOccupancyPrior): ParkingAvailabilityTier {
  switch (prior) {
    case 'low':
      return 'ample'
    case 'moderate':
      return 'limited'
    case 'high':
      return 'full'
  }
}

export function occupancyDisplayLabel(prior: LaybyOccupancyPrior): string {
  return prior
}

/** Format ETA seconds for desk copy (Mac DispatchStatusPanel parity). */
export function formatLaybyEta(seconds: number | null | undefined): string | null {
  if (seconds == null || !Number.isFinite(seconds) || seconds <= 0) return null
  const minutes = Math.max(1, Math.round(seconds / 60))
  if (minutes >= 60) {
    const hours = Math.floor(minutes / 60)
    const rem = minutes % 60
    return rem === 0 ? `~${hours} h` : `~${hours} h ${rem} min`
  }
  return `~${minutes} min`
}

/**
 * One-line summary matching Mac DispatchStatusPanel.laybyCard:
 * "Label · ETA ~N min · occupancy: low"
 */
export function predictedLaybyLine(layby: PredictedLayby): string {
  const parts = [layby.stop.label]
  const eta = formatLaybyEta(layby.estimatedArrivalSeconds ?? null)
  if (eta) parts.push(`ETA ${eta}`)
  parts.push(`occupancy: ${occupancyDisplayLabel(layby.occupancyPrior)}`)
  return parts.join(' · ')
}
