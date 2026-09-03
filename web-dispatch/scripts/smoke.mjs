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
console.log('fleet types smoke ok')
