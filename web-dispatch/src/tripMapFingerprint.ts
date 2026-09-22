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
  return `${trip.id}#${stops}#${driver}`
}
