import { Hono } from 'hono'
import type { GatewayConfig, OrgConfig } from '../types.js'
import type { MeterRegistry } from './meter.js'

const ORS_UPSTREAM = 'https://api.heigit.org/openrouteservice/v2'
const PELIAS_UPSTREAM = 'https://api.heigit.org/pelias/v1'

async function forward(
  url: string,
  init: RequestInit,
): Promise<Response> {
  const upstream = await fetch(url, init)
  const body = await upstream.arrayBuffer()
  const contentType = upstream.headers.get('Content-Type') ?? 'application/json; charset=utf-8'
  return new Response(body, {
    status: upstream.status,
    headers: { 'Content-Type': contentType },
  })
}

/** Registers /v1/proxy/* routes matching FleetORSProxy. */
export function createProxyRoutes(config: GatewayConfig, meters: MeterRegistry): Hono {
  const app = new Hono()
  const orsKey = config.orsAPIKey?.trim() ?? ''
  const configured = orsKey.length > 0

  app.get('/status', (c) => {
    const org = c.get('org') as OrgConfig
    const meter = meters.forOrg(org)
    return c.json(meter.status(configured))
  })

  if (!configured) {
    return app
  }

  const postPaths = [
    'directions/driving-hgv/geojson',
    'directions/driving-car/geojson',
    'matrix/driving-hgv',
    'matrix/driving-car',
  ] as const

  for (const path of postPaths) {
    app.post(`/ors/v2/${path}`, async (c) => {
      const org = c.get('org') as OrgConfig
      const meter = meters.forOrg(org)
      if (!meter.allows('orsRoute')) {
        return c.json({ error: 'Fleet ORS route daily cap reached.' }, 429)
      }
      const body = await c.req.arrayBuffer()
      meter.record('orsRoute')
      return forward(`${ORS_UPSTREAM}/${path}`, {
        method: 'POST',
        headers: {
          Authorization: orsKey,
          'Content-Type': 'application/json',
          Accept: 'application/json',
          'User-Agent': 'RouteFinderHostedGateway/0.1',
        },
        body,
      })
    })
  }

  app.get('/pelias/v1/search', async (c) => {
    const org = c.get('org') as OrgConfig
    const meter = meters.forOrg(org)
    if (!meter.allows('orsGeocode')) {
      return c.json({ error: 'Fleet ORS geocode daily cap reached.' }, 429)
    }
    const query = c.req.url.includes('?') ? c.req.url.slice(c.req.url.indexOf('?')) : ''
    meter.record('orsGeocode')
    return forward(`${PELIAS_UPSTREAM}/search${query}`, {
      method: 'GET',
      headers: {
        Authorization: orsKey,
        Accept: 'application/json',
        'User-Agent': 'RouteFinderHostedGateway/0.1',
      },
    })
  })

  return app
}
