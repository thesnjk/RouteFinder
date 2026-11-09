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

/** Mirrors web-dispatch/src/tripMapFingerprint.ts tripMapFetchFingerprint. */
function tripMapFetchFingerprint(parts) {
  const readiness = parts.orsReady ? 'ors-ready' : 'ors-pending'
  const weight =
    parts.weightTonnes != null && Number.isFinite(parts.weightTonnes)
      ? `w${Number(parts.weightTonnes).toFixed(2)}`
      : 'w-'
  return `${parts.tripFp}#${parts.pinsFp}#${parts.selectedVehicleId ?? ''}#${readiness}#${weight}`
}

const tripFp = tripMapFingerprint(baseTrip)
const pending = tripMapFetchFingerprint({
  tripFp,
  pinsFp: 'none',
  selectedVehicleId: 'veh-1',
  orsReady: false,
  weightTonnes: null,
})
const ready = tripMapFetchFingerprint({
  tripFp,
  pinsFp: 'none',
  selectedVehicleId: 'veh-1',
  orsReady: true,
  weightTonnes: null,
})
assert.notEqual(pending, ready)
assert.ok(pending.includes('ors-pending'))
assert.ok(ready.includes('ors-ready'))
assert.equal(
  tripMapFetchFingerprint({
    tripFp,
    pinsFp: 'none',
    selectedVehicleId: 'veh-1',
    orsReady: true,
    weightTonnes: 18,
  }),
  tripMapFetchFingerprint({
    tripFp,
    pinsFp: 'none',
    selectedVehicleId: 'veh-1',
    orsReady: true,
    weightTonnes: 18,
  }),
)
assert.notEqual(
  tripMapFetchFingerprint({
    tripFp,
    pinsFp: 'none',
    selectedVehicleId: 'veh-1',
    orsReady: true,
    weightTonnes: 18,
  }),
  tripMapFetchFingerprint({
    tripFp,
    pinsFp: 'none',
    selectedVehicleId: 'veh-1',
    orsReady: true,
    weightTonnes: 26,
  }),
)

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

/** Mirrors web-dispatch/src/orsRoutePreview.ts parse helper. */
function parseOrsGeoJsonCoordinates(payload) {
  if (!payload || typeof payload !== 'object') return []
  const features = Array.isArray(payload.features) ? payload.features : [payload]
  for (const feature of features) {
    if (!feature || typeof feature !== 'object') continue
    const geometry = feature.geometry
    if (!geometry || typeof geometry !== 'object') continue
    const { type, coordinates } = geometry
    if (!Array.isArray(coordinates) || coordinates.length === 0) continue
    if (type === 'LineString') {
      return coordinates.filter((p) => Array.isArray(p) && p.length >= 2).map((p) => [p[0], p[1]])
    }
    if (type === 'MultiLineString' && Array.isArray(coordinates[0])) {
      return coordinates[0].filter((p) => Array.isArray(p) && p.length >= 2).map((p) => [p[0], p[1]])
    }
  }
  return []
}

const sampleOrs = {
  type: 'FeatureCollection',
  features: [
    {
      type: 'Feature',
      geometry: {
        type: 'LineString',
        coordinates: [
          [1.2974, 52.6309],
          [0.8, 52.7],
          [0.3955, 52.7519],
        ],
      },
    },
  ],
}
const corridor = parseOrsGeoJsonCoordinates(sampleOrs)
assert.equal(corridor.length, 3)
assert.deepEqual(corridor[0], [1.2974, 52.6309])
assert.equal(parseOrsGeoJsonCoordinates({}).length, 0)

/** Mirrors web-dispatch/src/vehicleFilter.ts */
function filterVehicles(vehicles, query) {
  const q = String(query ?? '')
    .trim()
    .toLowerCase()
  if (!q) return vehicles
  return vehicles.filter((v) => {
    const label = String(v.label ?? '').toLowerCase()
    const plate = String(v.registrationPlate ?? '').toLowerCase()
    return label.includes(q) || plate.includes(q)
  })
}

const fleetUnits = [
  { id: '1', orgId: 'o', label: 'Unit 12', registrationPlate: 'AB12 CDE' },
  { id: '2', orgId: 'o', label: 'Spare artic', registrationPlate: null },
  { id: '3', orgId: 'o', label: 'Unit 7', registrationPlate: 'XY99 ZZZ' },
]
assert.equal(filterVehicles(fleetUnits, '').length, 3)
assert.equal(filterVehicles(fleetUnits, '  ').length, 3)
assert.equal(filterVehicles(fleetUnits, 'unit 12').length, 1)
assert.equal(filterVehicles(fleetUnits, 'xy99').length, 1)
assert.equal(filterVehicles(fleetUnits, 'nope').length, 0)

/** Mirrors web-dispatch/src/fleetRoster.ts */
function gpsAgeSeconds(trip, nowMs) {
  const raw = trip?.driverLocationRecordedAt
  if (!raw || trip?.driverLatitude == null || trip?.driverLongitude == null) return null
  const then = Date.parse(raw)
  if (!Number.isFinite(then)) return null
  return Math.max(0, Math.round((nowMs - then) / 1000))
}

function buildRosterRows(vehicles, tripByVehicleId, nowMs) {
  return vehicles.map((v) => {
    const trip = Object.prototype.hasOwnProperty.call(tripByVehicleId, v.id)
      ? tripByVehicleId[v.id]
      : null
    const defects = trip?.latestInspectionSummary?.defectCount ?? 0
    return {
      vehicleId: v.id,
      label: v.label,
      plate: v.registrationPlate ?? null,
      trip,
      gpsAgeSeconds: gpsAgeSeconds(trip, nowMs),
      hasDefects: defects > 0,
    }
  })
}

const now = Date.parse('2026-09-26T12:00:30Z')
const tripWithGps = {
  id: 't1',
  status: 'active',
  physicsETASeconds: 600,
  driverLatitude: 52.63,
  driverLongitude: 1.29,
  driverLocationRecordedAt: '2026-09-26T12:00:00Z',
  latestInspectionSummary: { vehicleLabel: 'Unit 12', defectCount: 2, completedAt: '2026-09-26T11:00:00Z' },
}
assert.equal(gpsAgeSeconds(tripWithGps, now), 30)
assert.equal(gpsAgeSeconds(null, now), null)
const rows = buildRosterRows(fleetUnits, { 1: tripWithGps, 2: null }, now)
assert.equal(rows.length, 3)
assert.equal(rows[0].gpsAgeSeconds, 30)
assert.equal(rows[0].hasDefects, true)
assert.equal(rows[1].trip, null)
assert.equal(rows[1].hasDefects, false)

function rosterDriverPins(rows) {
  const pins = []
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

const pins = rosterDriverPins(rows)
assert.equal(pins.length, 1)
assert.equal(pins[0].vehicleId, '1')
assert.equal(rosterDriverPins(buildRosterRows(fleetUnits, {}, now)).length, 0)

/** Mirrors web-dispatch/src/fleetHealthLabel.ts */
function isAuthFailureMessage(message) {
  const text = String(message).toLowerCase()
  return (
    text.includes('401') ||
    text.includes('403') ||
    text.includes('api key') ||
    text.includes('unauthorized')
  )
}

function fleetHealthLabel({ healthOk, authSucceeded, version, errorMessage }) {
  if (healthOk && authSucceeded) {
    if (version != null && String(version).length > 0) {
      return `Connected · version ${version}`
    }
    return 'Connected'
  }
  const detail = String(errorMessage ?? '').trim()
  if (healthOk && !authSucceeded) {
    if (detail && isAuthFailureMessage(detail)) {
      return `Auth failed · ${detail}`
    }
    return detail ? `Offline · ${detail}` : 'Offline'
  }
  if (!healthOk) {
    return detail ? `Offline · ${detail}` : 'Offline · health not ok'
  }
  return 'Offline'
}

assert.equal(
  fleetHealthLabel({ healthOk: true, authSucceeded: true, version: '1' }),
  'Connected · version 1',
)
assert.ok(
  fleetHealthLabel({
    healthOk: true,
    authSucceeded: false,
    errorMessage: 'HTTP 401: Fleet API key rejected',
  }).startsWith('Auth failed · '),
)
assert.equal(
  fleetHealthLabel({
    healthOk: true,
    authSucceeded: false,
    errorMessage: 'network timeout',
  }),
  'Offline · network timeout',
)
assert.ok(
  !fleetHealthLabel({
    healthOk: true,
    authSucceeded: false,
    errorMessage: 'network timeout',
  }).includes('Connected'),
)
assert.equal(
  fleetHealthLabel({ healthOk: false, authSucceeded: false }),
  'Offline · health not ok',
)

/** Mirrors web-dispatch/src/dispatchPushGate.ts */
function canPushTrip({ hasVehicle, hasResolvedStops, healthOk }) {
  return hasVehicle && hasResolvedStops && healthOk
}
function isPushBlockedByFleetHealth({ hasVehicle, hasResolvedStops, healthOk }) {
  return hasVehicle && hasResolvedStops && !healthOk
}
assert.equal(
  canPushTrip({ hasVehicle: true, hasResolvedStops: true, healthOk: true }),
  true,
)
assert.equal(
  canPushTrip({ hasVehicle: true, hasResolvedStops: true, healthOk: false }),
  false,
)
// App.tsx auto-calls refreshHealth on mount/client change so strangers are not stuck on
// "Not checked" — Push still requires healthOk (Mac startHealthPolling parity).
assert.equal(
  canPushTrip({ hasVehicle: true, hasResolvedStops: true, healthOk: false }),
  false,
  'auto-probe must succeed before Push; gate still requires healthOk',
)
assert.equal(
  isPushBlockedByFleetHealth({
    hasVehicle: true,
    hasResolvedStops: true,
    healthOk: false,
  }),
  true,
)
assert.equal(
  isPushBlockedByFleetHealth({
    hasVehicle: true,
    hasResolvedStops: false,
    healthOk: false,
  }),
  false,
)

/** Mirrors web-dispatch/src/rosterPickerFilter.ts */
function rosterPickerIncludes({ mode, gpsAgeSeconds, hasDefects, hasRosterData }) {
  switch (mode) {
    case 'all':
      return true
    case 'hideOffline':
      if (!hasRosterData) return true
      return gpsAgeSeconds != null
    case 'defectsOnly':
      return hasRosterData && hasDefects
    default:
      return true
  }
}
assert.equal(
  rosterPickerIncludes({
    mode: 'hideOffline',
    gpsAgeSeconds: null,
    hasDefects: false,
    hasRosterData: false,
  }),
  true,
)
assert.equal(
  rosterPickerIncludes({
    mode: 'hideOffline',
    gpsAgeSeconds: null,
    hasDefects: false,
    hasRosterData: true,
  }),
  false,
)
assert.equal(
  rosterPickerIncludes({
    mode: 'defectsOnly',
    gpsAgeSeconds: 1,
    hasDefects: true,
    hasRosterData: true,
  }),
  true,
)
assert.equal(
  rosterPickerIncludes({
    mode: 'defectsOnly',
    gpsAgeSeconds: 1,
    hasDefects: false,
    hasRosterData: true,
  }),
  false,
)

/** Mirrors web-dispatch/src/fleetProxyStatusLabel.ts for CI without a TS runner. */
const NEAR_CAP_FRACTION = 0.9
const NEAR_CAP_WARNING =
  'Near daily proxy cap — raise --route-daily-cap / --geocode-daily-cap or wait until tomorrow.'

function routesRemaining(status) {
  return Math.max(0, status.routeDailyCap - status.routesToday)
}

function geocodesRemaining(status) {
  return Math.max(0, status.geocodeDailyCap - status.geocodeToday)
}

function isNearCap(used, cap) {
  if (cap <= 0) return false
  return used >= cap * NEAR_CAP_FRACTION
}

function isNearAnyORSCap(status) {
  return (
    status.orsConfigured &&
    (isNearCap(status.routesToday, status.routeDailyCap) ||
      isNearCap(status.geocodeToday, status.geocodeDailyCap))
  )
}

function orsSummaryLine(status) {
  if (!status.orsConfigured) {
    return 'ORS proxy: off (start server with --ors-key for address search and driver routing)'
  }
  return (
    `ORS proxy: on · ${status.routesToday}/${status.routeDailyCap} routes · ${routesRemaining(status)} left` +
    ` · ${status.geocodeToday}/${status.geocodeDailyCap} geocodes · ${geocodesRemaining(status)} left`
  )
}

function nearCapWarning(status) {
  if (!isNearAnyORSCap(status)) return null
  return NEAR_CAP_WARNING
}

const proxyOk = {
  orsConfigured: true,
  routesToday: 12,
  routeDailyCap: 2000,
  geocodeToday: 40,
  geocodeDailyCap: 500,
}
assert.equal(routesRemaining(proxyOk), 1988)
assert.equal(geocodesRemaining(proxyOk), 460)
assert.equal(
  orsSummaryLine(proxyOk),
  'ORS proxy: on · 12/2000 routes · 1988 left · 40/500 geocodes · 460 left',
)
assert.equal(nearCapWarning(proxyOk), null)

const proxyNear = {
  orsConfigured: true,
  routesToday: 900,
  routeDailyCap: 1000,
  geocodeToday: 10,
  geocodeDailyCap: 500,
}
assert.equal(isNearAnyORSCap(proxyNear), true)
assert.equal(nearCapWarning(proxyNear), NEAR_CAP_WARNING)

const proxyOff = {
  orsConfigured: false,
  routesToday: 0,
  routeDailyCap: 100,
  geocodeToday: 0,
  geocodeDailyCap: 50,
}
assert.ok(orsSummaryLine(proxyOff).includes('off'))
assert.equal(nearCapWarning(proxyOff), null)

const proxyOver = {
  orsConfigured: true,
  routesToday: 2100,
  routeDailyCap: 2000,
  geocodeToday: 600,
  geocodeDailyCap: 500,
}
assert.equal(routesRemaining(proxyOver), 0)
assert.equal(geocodesRemaining(proxyOver), 0)

/** Mirrors web-dispatch/src/demoCorridor.ts — must match Mac norfolkDemoCorridor(). */
const NORWICH = { label: 'Norwich', latitude: 52.6309, longitude: 1.2974 }
const KINGS_LYNN = { label: "King's Lynn", latitude: 52.7519, longitude: 0.3955 }
function loadNorfolkDemoStops() {
  return { origin: { ...NORWICH }, destination: { ...KINGS_LYNN } }
}
const norfolk = loadNorfolkDemoStops()
assert.equal(norfolk.origin.latitude, 52.6309)
assert.equal(norfolk.origin.longitude, 1.2974)
assert.equal(norfolk.destination.latitude, 52.7519)
assert.equal(norfolk.destination.longitude, 0.3955)
assert.equal(norfolk.origin.label, 'Norwich')
assert.equal(norfolk.destination.label, "King's Lynn")
// Pre-seed stranger path: both stops non-null ⇒ Push gate can pass with vehicle + health.
assert.equal(
  canPushTrip({
    hasVehicle: true,
    hasResolvedStops: Boolean(norfolk.origin && norfolk.destination),
    healthOk: true,
  }),
  true,
)

/** Mirrors web-dispatch/src/bootstrapDemoFleet.ts pick helpers (Mac parity names). */
const DEMO_ORG_NAME = 'Demo Haulage Ltd'
const DEMO_VEHICLE_LABEL = 'Artic 1'
const DEMO_VEHICLE_PLATE = 'AB12 CDE'

function pickDemoOrg(orgs) {
  return orgs.find((o) => o.name === DEMO_ORG_NAME)
}

function pickDemoVehicle(vehicles) {
  return vehicles.find(
    (v) =>
      v.label === DEMO_VEHICLE_LABEL ||
      (v.registrationPlate != null && v.registrationPlate === DEMO_VEHICLE_PLATE),
  )
}

assert.equal(pickDemoOrg([{ id: '1', name: 'Other' }]), undefined)
assert.equal(pickDemoOrg([{ id: '1', name: 'Other' }, { id: '2', name: DEMO_ORG_NAME }])?.id, '2')
assert.equal(
  pickDemoVehicle([{ id: 'v1', orgId: '2', label: 'Unit 1', registrationPlate: null }]),
  undefined,
)
assert.equal(
  pickDemoVehicle([
    { id: 'v1', orgId: '2', label: 'Unit 1', registrationPlate: null },
    { id: 'v2', orgId: '2', label: DEMO_VEHICLE_LABEL, registrationPlate: DEMO_VEHICLE_PLATE },
  ])?.id,
  'v2',
)
assert.equal(
  pickDemoVehicle([{ id: 'v3', orgId: '2', label: 'Spare', registrationPlate: DEMO_VEHICLE_PLATE }])
    ?.id,
  'v3',
)

assert.equal(
  joinUrl('http://127.0.0.1:8080', '/v1/telematics/pings'),
  'http://127.0.0.1:8080/v1/telematics/pings',
)
assert.equal(joinUrl('/fleet', '/v1/telematics/pings?limit=50'), '/fleet/v1/telematics/pings?limit=50')
assert.equal(joinUrl('/fleet', '/v1/tacho/advisory'), '/fleet/v1/tacho/advisory')

/** Mirrors web-dispatch/src/connectionProfiles.ts migrateLegacyConnection. */
function migrateLegacyConnection(legacy) {
  const base =
    !legacy?.baseUrl ||
    legacy.baseUrl === 'http://127.0.0.1:8080' ||
    legacy.baseUrl === 'http://localhost:8080'
      ? '/fleet'
      : legacy.baseUrl
  return {
    profile: { id: 'migrated-default', name: 'Default depot', baseUrl: base },
    apiKey: legacy?.apiKey ?? '',
  }
}

const migrated = migrateLegacyConnection({
  baseUrl: 'http://127.0.0.1:8080',
  apiKey: 'tok',
})
assert.equal(migrated.profile.name, 'Default depot')
assert.equal(migrated.profile.baseUrl, '/fleet')
assert.equal(migrated.apiKey, 'tok')

/** Mirrors web-dispatch/src/canIDriveDesk.ts (partner Can-I-drive desk card). */
const DEFAULT_WEEKLY_DRIVE_SECONDS = 56 * 3600
const LEGAL_DISCLAIMER =
  'The digital tachograph is the legal record. This clock is a planning aid only.'

function formatBudget(seconds) {
  const totalMinutes = Math.max(0, Math.round(seconds / 60))
  const hours = Math.floor(totalMinutes / 60)
  const minutes = totalMinutes % 60
  if (hours > 0 && minutes > 0) return `${hours}h ${minutes}m`
  if (hours > 0) return `${hours}h`
  return `${minutes}m`
}

function evaluatePartnerAdvisory(advisory) {
  const continuous = advisory.remainingContinuousDriveSeconds
  const daily = advisory.remainingDailyDriveSeconds
  const weekly =
    advisory.remainingWeeklyDriveSeconds == null
      ? DEFAULT_WEEKLY_DRIVE_SECONDS
      : advisory.remainingWeeklyDriveSeconds
  const provider =
    advisory.provider && String(advisory.provider).trim().length > 0
      ? String(advisory.provider).trim()
      : 'partner'
  const sourceLabel = `partner advisory (${provider})`
  const canDrive = continuous > 0 && daily > 0 && weekly > 0
  let budgetReason
  if (canDrive) {
    budgetReason = `Yes — remaining continuous ${formatBudget(continuous)}, daily ${formatBudget(daily)}, weekly ${formatBudget(weekly)} from ${sourceLabel}.`
  } else if (continuous <= 0) {
    budgetReason = `No — continuous drive remaining is exhausted (${sourceLabel}). Take a mandatory break.`
  } else if (daily <= 0) {
    budgetReason = `No — daily drive remaining is exhausted (${sourceLabel}). End the driving day.`
  } else {
    budgetReason = `No — weekly drive remaining is exhausted (${sourceLabel}). End the driving week.`
  }
  return {
    canDrive,
    reason: `${budgetReason} ${LEGAL_DISCLAIMER}`,
    weeklySeconds: weekly,
  }
}

const yesDrive = evaluatePartnerAdvisory({
  remainingContinuousDriveSeconds: 3600,
  remainingDailyDriveSeconds: 7200,
  remainingWeeklyDriveSeconds: 100_000,
  provider: 'demo',
})
assert.equal(yesDrive.canDrive, true)
assert.ok(yesDrive.reason.startsWith('Yes —'))
assert.ok(yesDrive.reason.includes(LEGAL_DISCLAIMER))

const noWeekly = evaluatePartnerAdvisory({
  remainingContinuousDriveSeconds: 3600,
  remainingDailyDriveSeconds: 7200,
  remainingWeeklyDriveSeconds: 0,
  provider: 'demo',
})
assert.equal(noWeekly.canDrive, false)
assert.ok(noWeekly.reason.includes('weekly drive remaining is exhausted'))

const omittedWeekly = evaluatePartnerAdvisory({
  remainingContinuousDriveSeconds: 3600,
  remainingDailyDriveSeconds: 7200,
  provider: 'demo',
})
assert.equal(omittedWeekly.canDrive, true)
assert.equal(omittedWeekly.weeklySeconds, DEFAULT_WEEKLY_DRIVE_SECONDS)

/** Mirrors web-dispatch/src/tollAdvisoryAlongRouteMatcher.ts + ukTollAdvisoryCatalog.ts */
const EARTH_RADIUS_M = 6_371_000
function haversineMeters(lat1, lon1, lat2, lon2) {
  const toRad = (deg) => (deg * Math.PI) / 180
  const dLat = toRad(lat2 - lat1)
  const dLon = toRad(lon2 - lon1)
  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) * Math.sin(dLon / 2) ** 2
  return 2 * EARTH_RADIUS_M * Math.asin(Math.min(1, Math.sqrt(a)))
}

const SMOKE_TOLL_CATALOG = [
  {
    id: 'm6-toll',
    name: 'M6 Toll',
    latitude: 52.65,
    longitude: -1.75,
    approachRadiusMeters: 4000,
    indicativeCostGBP: 13.0,
  },
  {
    id: 'dartford-crossing',
    name: 'Dartford Crossing',
    latitude: 51.464,
    longitude: 0.258,
    approachRadiusMeters: 3500,
    indicativeCostGBP: 6.0,
  },
  {
    id: 'severn-crossings',
    name: 'Severn Bridge / Second Severn Crossing',
    latitude: 51.59,
    longitude: -2.7,
    approachRadiusMeters: 4000,
  },
]

function advisoriesAlongRoute(coordinates, catalog = SMOKE_TOLL_CATALOG) {
  if (coordinates.length < 2 || catalog.length === 0) return []
  const hits = []
  const seen = new Set()
  for (const advisory of catalog) {
    let firstIndex
    for (let index = 0; index < coordinates.length; index++) {
      const [lng, lat] = coordinates[index]
      if (
        haversineMeters(lat, lng, advisory.latitude, advisory.longitude) <=
        advisory.approachRadiusMeters
      ) {
        firstIndex = index
        break
      }
    }
    if (firstIndex != null && !seen.has(advisory.id)) {
      seen.add(advisory.id)
      hits.push({ index: firstIndex, advisory })
    }
  }
  return hits.sort((a, b) => a.index - b.index).map((h) => h.advisory)
}

function indicativeRouteTotalGBP(advisories) {
  const amounts = advisories.map((a) => a.indicativeCostGBP).filter((v) => v != null)
  if (amounts.length === 0) return null
  return amounts.reduce((sum, v) => sum + v, 0)
}

assert.deepEqual(advisoriesAlongRoute([]), [])
assert.deepEqual(advisoriesAlongRoute([[0, 0]]), [])

const dartfordM6 = advisoriesAlongRoute([
  [0.258, 51.464],
  [-0.5, 52.0],
  [-1.75, 52.65],
])
assert.equal(dartfordM6.length, 2)
assert.equal(dartfordM6[0].id, 'dartford-crossing')
assert.equal(dartfordM6[1].id, 'm6-toll')
assert.equal(indicativeRouteTotalGBP(dartfordM6), 19)

const severnOnly = advisoriesAlongRoute([
  [-2.7, 51.59],
  [-2.65, 51.6],
])
assert.equal(severnOnly.length, 1)
assert.equal(severnOnly[0].id, 'severn-crossings')
assert.equal(indicativeRouteTotalGBP(severnOnly), null)

/** Mirrors web-dispatch/src/vehicleComboLength.ts */
function clampTrailerCount(trailerCount) {
  if (!Number.isFinite(trailerCount)) return 0
  return Math.min(3, Math.max(0, Math.trunc(trailerCount)))
}

function suggestedOverallLengthMeters(trailerCount) {
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

assert.equal(suggestedOverallLengthMeters(0), 12)
assert.equal(suggestedOverallLengthMeters(1), 16.5)
assert.equal(suggestedOverallLengthMeters(2), 18.75)
assert.equal(suggestedOverallLengthMeters(3), 25.25)
assert.equal(suggestedOverallLengthMeters(-1), 12)
assert.equal(suggestedOverallLengthMeters(99), 25.25)

function buildOrsHgvDirectionsBody(stops, profile) {
  const DEFAULT_HGV = {
    lengthMeters: 16.5,
    widthMeters: 2.55,
    heightMeters: 4.0,
    weightTonnes: 40.0,
    axleLoadTonnes: 11.5,
  }
  const v = { ...DEFAULT_HGV, ...profile }
  return {
    coordinates: stops.map((s) => [s.longitude, s.latitude]),
    options: {
      profile_params: {
        restrictions: {
          length: v.lengthMeters,
          width: v.widthMeters,
          height: v.heightMeters,
          weight: v.weightTonnes,
          axleload: v.axleLoadTonnes,
        },
      },
    },
  }
}

const orsBody = buildOrsHgvDirectionsBody(
  [
    { longitude: 1.29, latitude: 52.63 },
    { longitude: 0.39, latitude: 52.75 },
  ],
  { lengthMeters: suggestedOverallLengthMeters(2), weightTonnes: 44 },
)
assert.equal(orsBody.options.profile_params.restrictions.length, 18.75)
assert.equal(orsBody.options.profile_params.restrictions.weight, 44)

console.log('fleet types smoke ok')
