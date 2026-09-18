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

console.log('fleet types smoke ok')
