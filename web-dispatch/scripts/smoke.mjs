import assert from 'node:assert/strict'

function joinUrl(baseUrl, path) {
  const base = baseUrl.replace(/\/$/, '')
  const suffix = path.startsWith('/') ? path : `/${path}`
  return `${base}${suffix}`
}

function authHeaders(apiKey) {
  if (!String(apiKey).trim()) {
    return { Accept: 'application/json', 'Content-Type': 'application/json' }
  }
  return {
    Accept: 'application/json',
    'Content-Type': 'application/json',
    Authorization: `Bearer ${String(apiKey).trim()}`,
  }
}

assert.equal(joinUrl('http://127.0.0.1:8080', '/health'), 'http://127.0.0.1:8080/health')
assert.equal(joinUrl('http://127.0.0.1:8080/', 'v1/orgs'), 'http://127.0.0.1:8080/v1/orgs')
assert.equal(authHeaders('').Authorization, undefined)
assert.equal(authHeaders('secret').Authorization, 'Bearer secret')
assert.equal(joinUrl('http://127.0.0.1:8080', '/v1/proxy/status'), 'http://127.0.0.1:8080/v1/proxy/status')
assert.equal(joinUrl('/fleet', '/v1/proxy/status'), '/fleet/v1/proxy/status')

function geocodeSearchUrl(baseUrl, text, options = {}) {
  const params = new URLSearchParams({
    text,
    size: String(options.size ?? 8),
    'boundary.country': 'GBR',
  })
  params.set('focus.point.lat', String(options.focusLat ?? 52.6309))
  params.set('focus.point.lon', String(options.focusLon ?? 1.2974))
  const base = baseUrl.replace(/\/$/, '')
  return `${base}/v1/proxy/pelias/v1/search?${params.toString()}`
}

const geoUrl = geocodeSearchUrl('http://127.0.0.1:8080', 'Norwich')
assert.ok(geoUrl.startsWith('http://127.0.0.1:8080/v1/proxy/pelias/v1/search?'))
assert.ok(geoUrl.includes('text=Norwich'))
assert.ok(geoUrl.includes('boundary.country=GBR'))
assert.ok(geoUrl.includes('focus.point.lat=52.6309'))
assert.equal(geocodeSearchUrl('/fleet', 'King\'s Lynn').startsWith('/fleet/v1/proxy/pelias/v1/search?'), true)

/** Mirrors web-dispatch/src/tripMapFingerprint.ts for CI without a TS runner. */
function roundCoord(value) {
  return Number(value).toFixed(5)
}

function tripMapFingerprint(trip) {
  if (!trip || !trip.stops || trip.stops.length === 0) return 'empty'
  const stops = trip.stops
    .map((s) => `${s.id}:${roundCoord(s.latitude)},${roundCoord(s.longitude)}:${s.role}:${s.sequence}`)
    .join('|')
  const driver =
    trip.driverLatitude != null && trip.driverLongitude != null
      ? `${roundCoord(trip.driverLatitude)},${roundCoord(trip.driverLongitude)}`
      : '-'
  return `${trip.id}#${stops}#${driver}`
}

const baseTrip = {
  id: 'trip-1',
  stops: [
    { id: 'a', latitude: 52.6309, longitude: 1.2974, role: 'origin', sequence: 0 },
    { id: 'b', latitude: 52.75, longitude: 0.4, role: 'destination', sequence: 1 },
  ],
  driverLatitude: 52.64,
  driverLongitude: 1.29,
  driverLocationRecordedAt: '2026-09-19T10:00:00Z',
}
const pollTick = {
  ...baseTrip,
  driverLocationRecordedAt: '2026-09-19T10:00:05Z',
}
const movedDriver = {
  ...baseTrip,
  driverLatitude: 52.65,
  driverLongitude: 1.28,
  driverLocationRecordedAt: '2026-09-19T10:00:10Z',
}
assert.equal(tripMapFingerprint(baseTrip), tripMapFingerprint(pollTick))
assert.notEqual(tripMapFingerprint(baseTrip), tripMapFingerprint(movedDriver))
assert.equal(tripMapFingerprint(null), 'empty')

/** Mirrors web-dispatch/src/inspectionSummary.ts for CI without a TS runner. */
function inspectionHasDefects(trip) {
  const summary = trip?.latestInspectionSummary
  return summary != null && summary.defectCount > 0
}

function inspectionSummaryLine(summary) {
  const plateSuffix = summary.registrationPlate ? ` (${summary.registrationPlate})` : ''
  return `${summary.vehicleLabel}${plateSuffix} — ${summary.defectCount} defect(s) at ${summary.completedAt}`
}

function inspectionToastMessage(summary) {
  const plateSuffix = summary.registrationPlate ? ` (${summary.registrationPlate})` : ''
  return `Walkaround: ${summary.vehicleLabel}${plateSuffix} — ${summary.defectCount} defect(s) reported`
}

function shouldAnnounceInspection(previousSummary, newSummary, lastAnnounced) {
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

const inspectionSummary = {
  vehicleLabel: 'Unit 1',
  registrationPlate: 'AB12 CDE',
  defectCount: 2,
  completedAt: '2026-09-22T12:00:00Z',
}
assert.equal(inspectionHasDefects({ latestInspectionSummary: inspectionSummary }), true)
assert.equal(inspectionHasDefects({ latestInspectionSummary: { ...inspectionSummary, defectCount: 0 } }), false)
assert.equal(inspectionHasDefects(null), false)
assert.ok(inspectionSummaryLine(inspectionSummary).includes('Unit 1 (AB12 CDE) — 2 defect(s)'))
assert.ok(inspectionToastMessage(inspectionSummary).startsWith('Walkaround: Unit 1'))
assert.equal(shouldAnnounceInspection(null, inspectionSummary, null), true)
assert.equal(shouldAnnounceInspection(inspectionSummary, inspectionSummary, inspectionSummary), false)
assert.equal(
  shouldAnnounceInspection(
    inspectionSummary,
    { ...inspectionSummary, defectCount: 3, completedAt: '2026-09-22T13:00:00Z' },
    inspectionSummary,
  ),
  true,
)

/** Proxy status parsing tolerates ORS-only and full forecast JSON. */
function parseProxyStatus(json) {
  const data = typeof json === 'string' ? JSON.parse(json) : json
  return {
    orsConfigured: Boolean(data.orsConfigured),
    routesToday: Number(data.routesToday ?? 0),
    routeDailyCap: Number(data.routeDailyCap ?? 0),
    geocodeToday: Number(data.geocodeToday ?? 0),
    geocodeDailyCap: Number(data.geocodeDailyCap ?? 0),
    tomTomConfigured: data.tomTomConfigured,
    openWeatherConfigured: data.openWeatherConfigured,
    tomTomToday: data.tomTomToday,
    tomTomDailyCap: data.tomTomDailyCap,
    openWeatherToday: data.openWeatherToday,
    openWeatherDailyCap: data.openWeatherDailyCap,
  }
}

const orsOnly = parseProxyStatus(
  '{"orsConfigured":true,"routesToday":1,"routeDailyCap":2000,"geocodeToday":2,"geocodeDailyCap":2000}',
)
assert.equal(orsOnly.orsConfigured, true)
assert.equal(orsOnly.tomTomConfigured, undefined)
assert.equal(orsOnly.openWeatherConfigured, undefined)

const fullProxy = parseProxyStatus({
  orsConfigured: true,
  routesToday: 1,
  routeDailyCap: 2000,
  geocodeToday: 2,
  geocodeDailyCap: 2000,
  tomTomConfigured: true,
  openWeatherConfigured: false,
  tomTomToday: 3,
  tomTomDailyCap: 500,
  openWeatherToday: 0,
  openWeatherDailyCap: 200,
})
assert.equal(fullProxy.tomTomConfigured, true)
assert.equal(fullProxy.openWeatherConfigured, false)
assert.equal(fullProxy.tomTomToday, 3)

/** Mirrors web-dispatch/src/fleetProxyError.ts */
const ORS_ROUTE_CAP_MESSAGE =
  'Fleet ORS daily cap reached. Ask the operator to raise the proxy budget or wait until tomorrow.'
const GEOCODE_CAP_MESSAGE =
  'Fleet geocode daily cap reached. Ask the operator to raise the proxy budget or wait until tomorrow.'

function fleetProxyUserMessage(status, body, kind = 'generic') {
  const snippet = String(body ?? '')
    .trim()
    .replace(/\n/g, ' ')
    .slice(0, 200)
  const lower = snippet.toLowerCase()
  const looksLikeCap =
    status === 429 || lower.includes('daily cap') || lower.includes('too many requests')
  if (looksLikeCap) {
    if (kind === 'geocode' || lower.includes('geocode')) return GEOCODE_CAP_MESSAGE
    if (kind === 'route' || lower.includes('route') || lower.includes('ors')) {
      return ORS_ROUTE_CAP_MESSAGE
    }
    if (lower.includes('geocode')) return GEOCODE_CAP_MESSAGE
    return ORS_ROUTE_CAP_MESSAGE
  }
  const prefix = kind === 'geocode' ? 'geocode' : kind === 'route' ? 'ORS route' : 'Fleet'
  if (status === 401 || status === 403) {
    if (snippet) return `${prefix} ${status}: ${snippet}`
    return `${prefix} ${status}: Fleet API key rejected. Check the shared key with the operator.`
  }
  if (snippet) return `${prefix} ${status}: ${snippet}`
  return `${prefix} ${status}`
}

assert.equal(
  fleetProxyUserMessage(429, 'Fleet ORS geocode daily cap reached.', 'geocode'),
  GEOCODE_CAP_MESSAGE,
)
assert.equal(
  fleetProxyUserMessage(429, 'Fleet ORS route daily cap reached.', 'route'),
  ORS_ROUTE_CAP_MESSAGE,
)
assert.equal(
  fleetProxyUserMessage(503, 'Fleet ORS route daily cap reached.', 'generic'),
  ORS_ROUTE_CAP_MESSAGE,
)
assert.equal(
  fleetProxyUserMessage(500, 'upstream timeout', 'geocode'),
  'geocode 500: upstream timeout',
)
assert.ok(fleetProxyUserMessage(401, '', 'generic').includes('API key'))

console.log('fleet types smoke ok')
