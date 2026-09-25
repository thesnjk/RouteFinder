/** Operator-facing fleet proxy failure copy (parity with Android FleetProxyErrorMapper / iOS RouteFailureMapper). */

export const ORS_ROUTE_CAP_MESSAGE =
  'Fleet ORS daily cap reached. Ask the operator to raise the proxy budget or wait until tomorrow.'

export const GEOCODE_CAP_MESSAGE =
  'Fleet geocode daily cap reached. Ask the operator to raise the proxy budget or wait until tomorrow.'

export type FleetProxyErrorKind = 'geocode' | 'route' | 'generic'

const BODY_SNIPPET_MAX = 200

/**
 * Maps fleet HTTP failures to actionable desk/driver copy.
 * Use kind `'geocode'` for Pelias search; `'route'` for ORS; `'generic'` for other fleet REST.
 */
export function fleetProxyUserMessage(
  status: number,
  body: string,
  kind: FleetProxyErrorKind = 'generic',
): string {
  const snippet = body.trim().replace(/\n/g, ' ').slice(0, BODY_SNIPPET_MAX)
  const lower = snippet.toLowerCase()
  const looksLikeCap =
    status === 429 || lower.includes('daily cap') || lower.includes('too many requests')

  if (looksLikeCap) {
    if (kind === 'geocode' || lower.includes('geocode')) {
      return GEOCODE_CAP_MESSAGE
    }
    if (kind === 'route' || lower.includes('route') || lower.includes('ors')) {
      return ORS_ROUTE_CAP_MESSAGE
    }
    // Generic 429 on desk (org/trip) — still point at proxy budget when body says so
    if (lower.includes('geocode')) return GEOCODE_CAP_MESSAGE
    return ORS_ROUTE_CAP_MESSAGE
  }

  const prefix =
    kind === 'geocode' ? 'geocode' : kind === 'route' ? 'ORS route' : 'Fleet'

  if (status === 401 || status === 403) {
    if (snippet) return `${prefix} ${status}: ${snippet}`
    return `${prefix} ${status}: Fleet API key rejected. Check the shared key with the operator.`
  }

  if (snippet) return `${prefix} ${status}: ${snippet}`
  return `${prefix} ${status}`
}
