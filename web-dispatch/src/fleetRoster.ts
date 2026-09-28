import type { FleetTrip, FleetVehicle } from './fleet/types'
import { inspectionHasDefects } from './inspectionSummary'

/** Max vehicles polled on the web desk roster (ICP 5–15 + headroom). */
export const ROSTER_VEHICLE_CAP = 20

export interface FleetVehicleStatus {
  vehicleId: string
  label: string
  plate?: string | null
  trip: FleetTrip | null
  gpsAgeSeconds: number | null
  hasDefects: boolean
}

/** Seconds since `driverLocationRecordedAt`, or null when GPS is absent / unparseable. */
export function gpsAgeSeconds(trip: FleetTrip | null | undefined, nowMs: number): number | null {
  const raw = trip?.driverLocationRecordedAt
  if (!raw || trip?.driverLatitude == null || trip?.driverLongitude == null) return null
  const then = Date.parse(raw)
  if (!Number.isFinite(then)) return null
  return Math.max(0, Math.round((nowMs - then) / 1000))
}

/**
 * Build roster rows from vehicles + a map of vehicleId → active trip (or null).
 * Preserves vehicle list order; callers should already apply filter + cap.
 */
export function buildRosterRows(
  vehicles: FleetVehicle[],
  tripByVehicleId: Record<string, FleetTrip | null>,
  nowMs: number,
): FleetVehicleStatus[] {
  return vehicles.map((v) => {
    const trip = Object.prototype.hasOwnProperty.call(tripByVehicleId, v.id)
      ? tripByVehicleId[v.id]
      : null
    return {
      vehicleId: v.id,
      label: v.label,
      plate: v.registrationPlate ?? null,
      trip,
      gpsAgeSeconds: gpsAgeSeconds(trip, nowMs),
      hasDefects: inspectionHasDefects(trip),
    }
  })
}

export function formatPhysicsEta(seconds: number | null | undefined): string {
  if (seconds == null || !Number.isFinite(seconds)) return '—'
  return `${Math.round(seconds / 60)} min`
}

export function formatGpsAge(ageSeconds: number | null): string {
  if (ageSeconds == null) return '—'
  if (ageSeconds < 60) return `${ageSeconds}s`
  const mins = Math.floor(ageSeconds / 60)
  if (mins < 60) return `${mins}m`
  return `${Math.floor(mins / 60)}h`
}

export interface RosterDriverPin {
  vehicleId: string
  label: string
  latitude: number
  longitude: number
}

/** Driver GPS pins from roster rows that have a published location. */
export function rosterDriverPins(rows: FleetVehicleStatus[]): RosterDriverPin[] {
  const pins: RosterDriverPin[] = []
  for (const row of rows) {
    const lat = row.trip?.driverLatitude
    const lon = row.trip?.driverLongitude
    if (lat == null || lon == null || !Number.isFinite(lat) || !Number.isFinite(lon)) continue
    pins.push({
      vehicleId: row.vehicleId,
      label: row.label,
      latitude: lat,
      longitude: lon,
    })
  }
  return pins
}

/** Stable fingerprint for fleet pin updates (5 d.p. coords). */
export function fleetPinsFingerprint(pins: RosterDriverPin[]): string {
  if (pins.length === 0) return 'none'
  return pins
    .map(
      (p) =>
        `${p.vehicleId}:${Number(p.latitude).toFixed(5)},${Number(p.longitude).toFixed(5)}`,
    )
    .join('|')
}
