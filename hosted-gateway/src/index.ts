import { serve } from '@hono/node-server'
import { loadConfig } from './config.js'
import { createGatewayApp } from './server.js'

const config = loadConfig()
const { app } = createGatewayApp(config)

console.log(
  `RouteFinder hosted gateway listening on 0.0.0.0:${config.port} (data=${config.dataDir})`,
)
if (config.orsAPIKey) {
  console.log('ORS proxy enabled (operator-paid).')
} else {
  console.log('ORS proxy disabled — set ORS_API_KEY so drivers need no HeiGIT keys.')
}
console.log(`Configured orgs: ${config.orgs.map((o) => o.name).join(', ')}`)

serve({ fetch: app.fetch, port: config.port, hostname: '0.0.0.0' })
