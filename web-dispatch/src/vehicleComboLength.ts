/** UK bumper-to-bumper overall length ladder (Swift `VehicleProfile.suggestedOverallLengthMeters`). */

/** Clamps trailer count to 0…3. */
export function clampTrailerCount(trailerCount: number): number {
  if (!Number.isFinite(trailerCount)) return 0
  return Math.min(3, Math.max(0, Math.trunc(trailerCount)))
}

/**
 * Ladder: rigid 12 m → artic 16.5 m → drawbar/road-train 18.75 m → EMS 25.25 m.
 */
export function suggestedOverallLengthMeters(trailerCount: number): number {
  switch (clampTrailerCount(trailerCount)) {
    case 0:
      return 12.0
    case 1:
      return 16.5
    case 2:
      return 18.75
    default:
      return 25.25
  }
}
