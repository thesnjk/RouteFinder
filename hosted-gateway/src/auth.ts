import { createMiddleware } from 'hono/factory'
import type { GatewayConfig } from './types.js'
import { findOrgByToken } from './config.js'

function extractToken(authorization: string | undefined, headerKey: string | undefined): string | null {
  if (authorization) {
    const prefix = 'Bearer '
    if (authorization.startsWith(prefix)) {
      const token = authorization.slice(prefix.length).trim()
      if (token) return token
    }
  }
  const fromHeader = headerKey?.trim()
  return fromHeader && fromHeader.length > 0 ? fromHeader : null
}

/** Requires a configured org bearer token on protected routes. */
export function orgAuthMiddleware(config: GatewayConfig) {
  return createMiddleware(async (c, next) => {
    if (c.req.method === 'OPTIONS') {
      await next()
      return
    }
    const token = extractToken(
      c.req.header('Authorization'),
      c.req.header('X-Fleet-API-Key'),
    )
    if (!token) {
      return c.json({ error: 'Unauthorized' }, 401)
    }
    const org = findOrgByToken(config, token)
    if (!org) {
      return c.json({ error: 'Unauthorized' }, 401)
    }
    c.set('org', org)
    await next()
  })
}
