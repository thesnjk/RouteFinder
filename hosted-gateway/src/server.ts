import { Hono } from 'hono'
import type { GatewayConfig } from './types.js'
import { corsMiddleware } from './cors.js'
import { orgAuthMiddleware } from './auth.js'
import { StoreRegistry } from './fleet/store.js'
import { EventHub } from './fleet/eventHub.js'
import { createFleetRoutes } from './fleet/routes.js'
import { MeterRegistry } from './proxy/meter.js'
import { createProxyRoutes } from './proxy/ors.js'

export interface GatewayApp {
  app: Hono
  stores: StoreRegistry
  meters: MeterRegistry
  eventHub: EventHub
  config: GatewayConfig
}

/** Builds the Hono app matching RouteFinderFleetServer route surface. */
export function createGatewayApp(config: GatewayConfig): GatewayApp {
  const app = new Hono()
  const stores = new StoreRegistry(config.dataDir)
  const meters = new MeterRegistry(config.dataDir)
  const eventHub = new EventHub(15)

  app.use('*', corsMiddleware)

  app.get('/health', (c) => c.json({ ok: true, version: '1' }))

  app.use('/v1/*', orgAuthMiddleware(config))

  app.route('/v1', createFleetRoutes(stores, eventHub))
  app.route('/v1/proxy', createProxyRoutes(config, meters))

  return { app, stores, meters, eventHub, config }
}
