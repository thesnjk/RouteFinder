import type { FleetTrip } from './fleet/types'

/** Rounds a coordinate for fingerprint stability (~1 m at UK latitudes). */
function roundCoord(value: number): string {
  return value.toFixed(5)
}

/**
 * Stable fingerprint for trip map geometry.
 *
 * Ignores object identity and `driverLocationRecordedAt` so 5 s poll ticks that
 * only refresh timestamps do not tear down MapLibre markers.
 */
export function tripMapFingerprint(trip: FleetTrip | null): string {
  if (!trip || trip.stops.length === 0) return 'empty'
  const stops = trip.stops
    .map((s) => `${s.id}:${roundCoord(s.latitude)},${roundCoord(s.longitude)}:${s.role}:${s.sequence}`)
    .join('|')
  const driver =
    trip.driverLatitude != null && trip.driverLongitude != null
      ? `${roundCoord(trip.driverLatitude)},${roundCoord(trip.driverLongitude)}`
      : '-'
  const layby =
    trip.predictedLayby?.stop?.coordinate != null
      ? `${trip.predictedLayby.stop.id}:${roundCoord(trip.predictedLayby.stop.coordinate.latitude)},${roundCoord(trip.predictedLayby.stop.coordinate.longitude)}:${trip.predictedLayby.occupancyPrior}`
      : '-'
  return `${trip.id}#${stops}#${driver}#${layby}`
}

/**
 * Full fetch fingerprint for corridor + pins redraw.
 *
 * Includes ORS client readiness so a straight-line fallback drawn while health
 * was red re-fetches the HGV corridor after Test /health becomes Connected.
 */
export function tripMapFetchFingerprint(parts: {
  tripFp: string
  pinsFp: string
  selectedVehicleId?: string | null
  orsReady: boolean
  weightTonnes?: number | null
  lengthMeters?: number | null
}): string {
  const readiness = parts.orsReady ? 'ors-ready' : 'ors-pending'
  const weight =
    parts.weightTonnes != null && Number.isFinite(parts.weightTonnes)
      ? `w${parts.weightTonnes.toFixed(2)}`
      : 'w-'
  const length =
    parts.lengthMeters != null && Number.isFinite(parts.lengthMeters)
      ? `l${parts.lengthMeters.toFixed(2)}`
      : 'l-'
  return `${parts.tripFp}#${parts.pinsFp}#${parts.selectedVehicleId ?? ''}#${readiness}#${weight}#${length}`
}
