import { createMiddleware } from 'hono/factory'

const ALLOW_ORIGIN = '*'
const ALLOW_METHODS = 'GET, POST, PUT, OPTIONS'
const ALLOW_HEADERS = 'Authorization, Content-Type, X-Fleet-API-Key'

/** CORS middleware matching FleetCORSMiddleware for browser dispatch consoles. */
export const corsMiddleware = createMiddleware(async (c, next) => {
  if (c.req.method === 'OPTIONS') {
    c.header('Access-Control-Allow-Origin', ALLOW_ORIGIN)
    c.header('Access-Control-Allow-Methods', ALLOW_METHODS)
    c.header('Access-Control-Allow-Headers', ALLOW_HEADERS)
    return c.body(null, 204)
  }
  await next()
  c.header('Access-Control-Allow-Origin', ALLOW_ORIGIN)
  c.header('Access-Control-Allow-Methods', ALLOW_METHODS)
  c.header('Access-Control-Allow-Headers', ALLOW_HEADERS)
})
