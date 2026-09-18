import { mkdtempSync, rmSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { join } from 'node:path'
import { afterEach, describe, expect, it } from 'vitest'
import { createGatewayApp } from '../src/server.js'
import type { GatewayConfig, OrgConfig } from '../src/types.js'

const demoOrg: OrgConfig = {
  id: '11111111-1111-1111-1111-111111111111',
  name: 'Demo Haulage Ltd',
  bearerToken: 'test-token-alpha',
  routeDailyCap: 100,
  geocodeDailyCap: 100,
}

function makeConfig(dataDir: string, orsAPIKey: string | null = 'fake-ors-key'): GatewayConfig {
  return {
    port: 0,
    dataDir,
    orsAPIKey,
    orgs: [demoOrg],
    trustProxy: false,
  }
}

const dirs: string[] = []

function tempDir(): string {
  const dir = mkdtempSync(join(tmpdir(), 'rf-gw-'))
  dirs.push(dir)
  return dir
}

afterEach(() => {
  while (dirs.length) {
    const dir = dirs.pop()
    if (dir) rmSync(dir, { recursive: true, force: true })
  }
})

describe('auth + health', () => {
  it('health is unauthenticated', async () => {
    const { app } = createGatewayApp(makeConfig(tempDir()))
    const res = await app.request('/health')
    expect(res.status).toBe(200)
    expect(await res.json()).toEqual({ ok: true, version: '1' })
  })

  it('rejects missing token on /v1', async () => {
    const { app } = createGatewayApp(makeConfig(tempDir()))
    const res = await app.request('/v1/orgs')
    expect(res.status).toBe(401)
  })

  it('rejects wrong token', async () => {
    const { app } = createGatewayApp(makeConfig(tempDir()))
    const res = await app.request('/v1/orgs', {
      headers: { Authorization: 'Bearer wrong' },
    })
    expect(res.status).toBe(401)
  })

  it('accepts Bearer and X-Fleet-API-Key', async () => {
    const { app } = createGatewayApp(makeConfig(tempDir()))
    const bearer = await app.request('/v1/orgs', {
      headers: { Authorization: 'Bearer test-token-alpha' },
    })
    expect(bearer.status).toBe(200)
    const header = await app.request('/v1/orgs', {
      headers: { 'X-Fleet-API-Key': 'test-token-alpha' },
    })
    expect(header.status).toBe(200)
  })
})

describe('fleet round-trip', () => {
  it('creates vehicle, pushes trip, returns active trip', async () => {
    const { app } = createGatewayApp(makeConfig(tempDir()))
    const headers = {
      Authorization: 'Bearer test-token-alpha',
      'Content-Type': 'application/json',
    }

    const orgsRes = await app.request('/v1/orgs', { headers })
    const orgs = (await orgsRes.json()) as Array<{ id: string; name: string }>
    expect(orgs.length).toBeGreaterThanOrEqual(1)
    const orgId = orgs[0].id

    const vehicleRes = await app.request('/v1/vehicles', {
      method: 'POST',
      headers,
      body: JSON.stringify({
        orgId,
        label: 'Artic 1',
        registrationPlate: 'AB12 CDE',
      }),
    })
    expect(vehicleRes.status).toBe(200)
    const vehicle = (await vehicleRes.json()) as { id: string }

    const tripRes = await app.request('/v1/trips', {
      method: 'POST',
      headers,
      body: JSON.stringify({
        orgId,
        vehicleId: vehicle.id,
        status: 'draft',
        stops: [
          {
            id: 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
            sequence: 0,
            label: 'Origin',
            latitude: 51.95,
            longitude: 1.35,
            role: 'origin',
          },
          {
            id: 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
            sequence: 1,
            label: 'Destination',
            latitude: 53.48,
            longitude: -2.24,
            role: 'destination',
          },
        ],
        companyBreaks: [],
        updatedAt: new Date().toISOString(),
      }),
    })
    expect(tripRes.status).toBe(200)
    const trip = (await tripRes.json()) as { id: string; status: string; vehicleId: string }
    expect(trip.status).toBe('dispatched')

    const activeRes = await app.request(`/v1/vehicles/${vehicle.id}/active-trip`, { headers })
    expect(activeRes.status).toBe(200)
    const active = (await activeRes.json()) as { id: string }
    expect(active.id).toBe(trip.id)

    const emptyRes = await app.request(
      '/v1/vehicles/99999999-9999-9999-9999-999999999999/active-trip',
      { headers },
    )
    expect(emptyRes.status).toBe(204)
  })
})

describe('proxy metering', () => {
  it('reports orsConfigured and persists counts across meter reload', async () => {
    const dataDir = tempDir()
    const first = createGatewayApp(makeConfig(dataDir, 'fake-ors-key'))
    const headers = { Authorization: 'Bearer test-token-alpha' }

    const status1 = await first.app.request('/v1/proxy/status', { headers })
    expect(status1.status).toBe(200)
    const body1 = (await status1.json()) as {
      orsConfigured: boolean
      routesToday: number
      geocodeToday: number
    }
    expect(body1.orsConfigured).toBe(true)
    expect(body1.routesToday).toBe(0)

    // Record via meter directly (avoid real HeiGIT calls).
    const meter = first.meters.forOrg(demoOrg)
    meter.record('orsRoute')
    meter.record('orsGeocode')
    meter.record('orsGeocode')

    const status2 = await first.app.request('/v1/proxy/status', { headers })
    const body2 = (await status2.json()) as { routesToday: number; geocodeToday: number }
    expect(body2.routesToday).toBe(1)
    expect(body2.geocodeToday).toBe(2)

    // Simulate process restart: forget cache and create a new app on same data dir.
    first.meters.forget(demoOrg.id)
    const second = createGatewayApp(makeConfig(dataDir, 'fake-ors-key'))
    const status3 = await second.app.request('/v1/proxy/status', { headers })
    const body3 = (await status3.json()) as { routesToday: number; geocodeToday: number }
    expect(body3.routesToday).toBe(1)
    expect(body3.geocodeToday).toBe(2)
  })

  it('reports orsConfigured false when key missing', async () => {
    const { app } = createGatewayApp(makeConfig(tempDir(), null))
    const res = await app.request('/v1/proxy/status', {
      headers: { Authorization: 'Bearer test-token-alpha' },
    })
    const body = (await res.json()) as { orsConfigured: boolean }
    expect(body.orsConfigured).toBe(false)
  })
})

describe('telematics ingest', () => {
  it('accepts webhook stub and persists', async () => {
    const { app } = createGatewayApp(makeConfig(tempDir()))
    const headers = {
      Authorization: 'Bearer test-token-alpha',
      'Content-Type': 'application/json',
    }
    const res = await app.request('/v1/telematics/ingest', {
      method: 'POST',
      headers,
      body: JSON.stringify({
        vehicleId: 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
        latitude: 52.63,
        longitude: 1.3,
        provider: 'geotab',
        vehicleLabel: 'Artic 1',
      }),
    })
    expect(res.status).toBe(200)
    const body = (await res.json()) as { vehicleLabel: string; provider: string }
    expect(body.vehicleLabel).toBe('Artic 1')
    expect(body.provider).toBe('geotab')
  })
})
