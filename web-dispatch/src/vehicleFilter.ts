import type { FleetVehicle } from './fleet/types'

/**
 * Filter fleet vehicles by label or registration plate (case-insensitive).
 * Empty / whitespace query returns all vehicles.
 */
export function filterVehicles(vehicles: FleetVehicle[], query: string): FleetVehicle[] {
  const q = query.trim().toLowerCase()
  if (!q) return vehicles
  return vehicles.filter((v) => {
    const label = v.label.toLowerCase()
    const plate = (v.registrationPlate ?? '').toLowerCase()
    return label.includes(q) || plate.includes(q)
  })
}
