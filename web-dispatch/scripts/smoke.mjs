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

console.log('fleet types smoke ok')
