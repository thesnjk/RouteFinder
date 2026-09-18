import { Hono } from 'hono'
import { streamSSE } from 'hono/streaming'
import { randomUUID } from 'node:crypto'
import type { FleetTrip, FleetTripSnapshot, FleetVehicle, OrgConfig } from '../types.js'
import type { EventHub } from './eventHub.js'
import type { StoreRegistry } from './store.js'

/** Fleet REST + SSE routes matching FleetRouterBuilder. */
export function createFleetRoutes(stores: StoreRegistry, eventHub: EventHub): Hono {
  const app = new Hono()

  app.get('/orgs', (c) => {
    const org = c.get('org') as OrgConfig
    return c.json(stores.forOrg(org).orgs())
  })

  app.post('/orgs', async (c) => {
    const org = c.get('org') as OrgConfig
    const body = (await c.req.json()) as { name?: string }
    if (!body.name?.trim()) {
      return c.json({ error: 'name is required' }, 400)
    }
    return c.json(stores.forOrg(org).createOrg(body.name.trim()))
  })

  app.get('/orgs/:orgId/vehicles', (c) => {
    const org = c.get('org') as OrgConfig
    return c.json(stores.forOrg(org).vehicles(c.req.param('orgId')))
  })

  app.post('/vehicles', async (c) => {
    const org = c.get('org') as OrgConfig
    const body = (await c.req.json()) as FleetVehicle
    if (!body.orgId || !body.label) {
      return c.json({ error: 'orgId and label are required' }, 400)
    }
    const vehicle: FleetVehicle = {
      id: body.id || randomUUID(),
      orgId: body.orgId,
      label: body.label,
      registrationPlate: body.registrationPlate ?? null,
      profile: body.profile ?? null,
    }
    return c.json(stores.forOrg(org).registerVehicle(vehicle))
  })

  app.post('/trips', async (c) => {
    const org = c.get('org') as OrgConfig
    const body = (await c.req.json()) as FleetTrip
    if (!body.orgId || !body.vehicleId || !Array.isArray(body.stops)) {
      return c.json({ error: 'orgId, vehicleId, and stops are required' }, 400)
    }
    const trip: FleetTrip = {
      ...body,
      id: body.id || randomUUID(),
      stops: body.stops.map((s) => ({
        ...s,
        id: s.id || randomUUID(),
      })),
      updatedAt: body.updatedAt || new Date().toISOString(),
      companyBreaks: body.companyBreaks ?? [],
    }
    const pushed = stores.forOrg(org).pushTrip(trip)
    eventHub.publish({
      kind: 'tripPushed',
      vehicleId: pushed.vehicleId,
      tripId: pushed.id,
      timestamp: new Date().toISOString(),
    })
    return c.json(pushed)
  })

  app.get('/vehicles/:vehicleId/active-trip', (c) => {
    const org = c.get('org') as OrgConfig
    const trip = stores.forOrg(org).activeTrip(c.req.param('vehicleId'))
    if (!trip) return c.body(null, 204)
    return c.json(trip)
  })

  app.get('/vehicles/:vehicleId/events', (c) => {
    const vehicleId = c.req.param('vehicleId')
    const heartbeatMs = eventHub.heartbeatIntervalSeconds * 1000
    return streamSSE(c, async (stream) => {
      let closed = false
      const unsubscribe = eventHub.subscribe(vehicleId, (event) => {
        if (closed) return
        void stream.writeSSE({ data: JSON.stringify(event) })
      })
      const heartbeat = setInterval(() => {
        if (closed) return
        void stream.writeSSE({
          data: JSON.stringify({
            kind: 'heartbeat',
            vehicleId,
            tripId: null,
            timestamp: new Date().toISOString(),
          }),
        })
      }, heartbeatMs)

      stream.onAbort(() => {
        closed = true
        clearInterval(heartbeat)
        unsubscribe()
      })

      // Keep the stream open until the client disconnects.
      await new Promise<void>((resolve) => {
        const check = setInterval(() => {
          if (closed) {
            clearInterval(check)
            resolve()
          }
        }, 500)
      })
    })
  })

  app.get('/trips/:tripId', (c) => {
    const org = c.get('org') as OrgConfig
    const trip = stores.forOrg(org).trip(c.req.param('tripId'))
    if (!trip) return c.json({ error: 'Not found' }, 404)
    return c.json(trip)
  })

  app.put('/trips/:tripId/snapshot', async (c) => {
    const org = c.get('org') as OrgConfig
    const tripId = c.req.param('tripId')
    const snapshot = (await c.req.json()) as FleetTripSnapshot
    if (snapshot.tripId !== tripId) {
      return c.json({ error: 'Trip id in path and body must match.' }, 400)
    }
    try {
      return c.json(stores.forOrg(org).applySnapshot(snapshot))
    } catch {
      return c.json({ error: 'Trip not found' }, 404)
    }
  })

  app.post('/telematics/ingest', async (c) => {
    const org = c.get('org') as OrgConfig
    const body = (await c.req.json()) as {
      vehicleId?: string
      latitude?: number
      longitude?: number
      recordedAt?: string
      provider?: string
      vehicleLabel?: string
    }
    if (!body.vehicleId || typeof body.latitude !== 'number' || typeof body.longitude !== 'number') {
      return c.json({ error: 'vehicleId, latitude, and longitude are required' }, 400)
    }
    return c.json(
      stores.forOrg(org).ingestTelematics({
        vehicleId: body.vehicleId,
        latitude: body.latitude,
        longitude: body.longitude,
        recordedAt: body.recordedAt,
        provider: body.provider,
        vehicleLabel: body.vehicleLabel,
      }),
    )
  })

  return app
}
