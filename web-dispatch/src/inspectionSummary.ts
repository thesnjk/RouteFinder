import type { FleetTrip, TripBriefInspectionSummary } from './fleet/types'

/** True when the trip carries a walkaround with at least one defect. */
export function inspectionHasDefects(trip: FleetTrip | null | undefined): boolean {
  const summary = trip?.latestInspectionSummary
  return summary != null && summary.defectCount > 0
}

/**
 * One-line summary matching Mac DispatchStatusPanel copy:
 * "Vehicle (PLATE) — N defect(s) at <local time>"
 */
export function inspectionSummaryLine(summary: TripBriefInspectionSummary): string {
  const plateSuffix = summary.registrationPlate ? ` (${summary.registrationPlate})` : ''
  let timestamp = summary.completedAt
  try {
    const date = new Date(summary.completedAt)
    if (!Number.isNaN(date.getTime())) {
      timestamp = date.toLocaleString(undefined, {
        dateStyle: 'medium',
        timeStyle: 'short',
      })
    }
  } catch {
    /* keep raw ISO */
  }
  return `${summary.vehicleLabel}${plateSuffix} — ${summary.defectCount} defect(s) at ${timestamp}`
}

/** Toast copy when a new defect walkaround arrives on poll (Mac DispatchInspectionAnnouncer). */
export function inspectionToastMessage(summary: TripBriefInspectionSummary): string {
  const plateSuffix = summary.registrationPlate ? ` (${summary.registrationPlate})` : ''
  return `Walkaround: ${summary.vehicleLabel}${plateSuffix} — ${summary.defectCount} defect(s) reported`
}

/**
 * Whether dispatch should announce a newly observed inspection summary.
 * Mirrors Swift DispatchInspectionAnnouncer.shouldAnnounce.
 */
export function shouldAnnounceInspection(
  previousSummary: TripBriefInspectionSummary | null | undefined,
  newSummary: TripBriefInspectionSummary | null | undefined,
  lastAnnounced: TripBriefInspectionSummary | null | undefined,
): boolean {
  if (!newSummary || newSummary.defectCount <= 0) return false
  if (
    lastAnnounced &&
    lastAnnounced.completedAt === newSummary.completedAt &&
    lastAnnounced.defectCount === newSummary.defectCount
  ) {
    return false
  }
  if (!previousSummary) return true
  if (previousSummary.defectCount < newSummary.defectCount) return true
  if (previousSummary.completedAt !== newSummary.completedAt) return true
  return false
}

/** Decode base64 PDF and trigger a browser download. */
export function downloadInspectionPdf(base64: string, filename = 'walkaround-report.pdf'): void {
  const binary = atob(base64)
  const bytes = new Uint8Array(binary.length)
  for (let i = 0; i < binary.length; i++) {
    bytes[i] = binary.charCodeAt(i)
  }
  const blob = new Blob([bytes], { type: 'application/pdf' })
  const url = URL.createObjectURL(blob)
  const anchor = document.createElement('a')
  anchor.href = url
  anchor.download = filename
  anchor.click()
  URL.revokeObjectURL(url)
}
