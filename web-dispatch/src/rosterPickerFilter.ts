import type { FleetVehicleStatus } from './fleetRoster'

/** Desk vehicle-picker / roster display mode (parity with Mac DispatchRosterPickerMode). */
export type RosterPickerMode = 'all' | 'hideOffline' | 'defectsOnly'

/**
 * Whether a vehicle should appear for the given mode and roster status.
 * Unknown (no roster row yet) stays visible in hideOffline; defectsOnly requires known defects.
 */
export function rosterPickerIncludes(options: {
  mode: RosterPickerMode
  gpsAgeSeconds: number | null
  hasDefects: boolean
  hasRosterData: boolean
}): boolean {
  const { mode, gpsAgeSeconds, hasDefects, hasRosterData } = options
  switch (mode) {
    case 'all':
      return true
    case 'hideOffline':
      if (!hasRosterData) return true
      return gpsAgeSeconds != null
    case 'defectsOnly':
      return hasRosterData && hasDefects
  }
}

/** Filter roster rows by picker mode (preserves order). */
export function filterRosterRows(
  rows: FleetVehicleStatus[],
  mode: RosterPickerMode,
): FleetVehicleStatus[] {
  return rows.filter((row) =>
    rosterPickerIncludes({
      mode,
      gpsAgeSeconds: row.gpsAgeSeconds,
      hasDefects: row.hasDefects,
      hasRosterData: true,
    }),
  )
}

/** Filter vehicle IDs after text filter using optional roster status map. */
export function filterVehicleIdsByRosterMode(
  orderedIds: string[],
  mode: RosterPickerMode,
  statusById: Record<string, { gpsAgeSeconds: number | null; hasDefects: boolean }>,
): string[] {
  return orderedIds.filter((id) => {
    const status = statusById[id]
    if (status) {
      return rosterPickerIncludes({
        mode,
        gpsAgeSeconds: status.gpsAgeSeconds,
        hasDefects: status.hasDefects,
        hasRosterData: true,
      })
    }
    return rosterPickerIncludes({
      mode,
      gpsAgeSeconds: null,
      hasDefects: false,
      hasRosterData: false,
    })
  })
}
