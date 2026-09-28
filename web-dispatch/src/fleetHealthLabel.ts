/**
 * Pure desk health-pill labeling (parity with Mac FleetServerHealthLabel / Android FleetConnectionGate).
 * Distinguishes Auth failed (key mismatch) from Offline (server/LAN / non-auth probe failure).
 */

export function isAuthFailureMessage(message: string): boolean {
  const text = message.toLowerCase()
  return (
    text.includes('401') ||
    text.includes('403') ||
    text.includes('api key') ||
    text.includes('unauthorized')
  )
}

/**
 * Operator-facing health pill text after /health and optional auth probe.
 *
 * @param healthOk - GET /health returned ok
 * @param authSucceeded - protected probe succeeded (e.g. /v1/proxy/status)
 * @param version - fleet server version when connected
 * @param errorMessage - probe/health error detail
 */
export function fleetHealthLabel(options: {
  healthOk: boolean
  authSucceeded: boolean
  version?: string | null
  errorMessage?: string | null
}): string {
  const { healthOk, authSucceeded, version, errorMessage } = options
  if (healthOk && authSucceeded) {
    if (version != null && String(version).length > 0) {
      return `Connected · version ${version}`
    }
    return 'Connected'
  }
  const detail = (errorMessage ?? '').trim()
  if (healthOk && !authSucceeded) {
    if (detail && isAuthFailureMessage(detail)) {
      return `Auth failed · ${detail}`
    }
    // Health succeeded but probe failed for a non-auth reason — not "Connected".
    return detail ? `Offline · ${detail}` : 'Offline'
  }
  if (!healthOk) {
    return detail ? `Offline · ${detail}` : 'Offline · health not ok'
  }
  return 'Offline'
}
