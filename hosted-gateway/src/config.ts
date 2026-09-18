import { readFileSync, existsSync } from 'node:fs'
import { resolve } from 'node:path'
import { randomUUID } from 'node:crypto'
import type { GatewayConfig, OrgConfig } from './types.js'

const DEFAULT_ROUTE_CAP = 2000
const DEFAULT_GEOCODE_CAP = 2000

function parseOrgs(raw: unknown): OrgConfig[] {
  if (!Array.isArray(raw)) {
    throw new Error('Orgs config must be a JSON array.')
  }
  const orgs: OrgConfig[] = []
  for (const entry of raw) {
    if (!entry || typeof entry !== 'object') {
      throw new Error('Each org entry must be an object.')
    }
    const row = entry as Record<string, unknown>
    const bearerToken = String(row.bearerToken ?? '').trim()
    if (!bearerToken) {
      throw new Error('Each org requires a non-empty bearerToken.')
    }
    const id = String(row.id ?? randomUUID()).trim()
    const name = String(row.name ?? 'Fleet Org').trim() || 'Fleet Org'
    orgs.push({
      id,
      name,
      bearerToken,
      routeDailyCap:
        typeof row.routeDailyCap === 'number' ? row.routeDailyCap : DEFAULT_ROUTE_CAP,
      geocodeDailyCap:
        typeof row.geocodeDailyCap === 'number' ? row.geocodeDailyCap : DEFAULT_GEOCODE_CAP,
    })
  }
  if (orgs.length === 0) {
    throw new Error('At least one org must be configured.')
  }
  const tokens = new Set<string>()
  for (const org of orgs) {
    if (tokens.has(org.bearerToken)) {
      throw new Error('Duplicate bearerToken in orgs config.')
    }
    tokens.add(org.bearerToken)
  }
  return orgs
}

function loadOrgsFromEnvOrFile(): OrgConfig[] {
  const envJson = process.env.ROUTEFINDER_ORGS_JSON?.trim()
  if (envJson) {
    return parseOrgs(JSON.parse(envJson))
  }
  const configPath =
    process.env.ROUTEFINDER_ORGS_FILE?.trim() ||
    resolve(process.cwd(), 'config', 'orgs.json')
  if (!existsSync(configPath)) {
    // Dev/test default: single org with a known token.
    return [
      {
        id: '11111111-1111-1111-1111-111111111111',
        name: 'Demo Haulage Ltd',
        bearerToken: 'dev-org-token',
        routeDailyCap: DEFAULT_ROUTE_CAP,
        geocodeDailyCap: DEFAULT_GEOCODE_CAP,
      },
    ]
  }
  const text = readFileSync(configPath, 'utf8')
  return parseOrgs(JSON.parse(text))
}

/** Loads gateway configuration from environment and optional orgs file. */
export function loadConfig(overrides: Partial<GatewayConfig> = {}): GatewayConfig {
  const ors =
    process.env.ORS_API_KEY?.trim() ||
    process.env.ROUTEFINDER_ORS_API_KEY?.trim() ||
    null
  return {
    port: Number(process.env.PORT ?? overrides.port ?? 8787),
    dataDir: overrides.dataDir ?? process.env.DATA_DIR?.trim() ?? resolve(process.cwd(), 'data'),
    orsAPIKey: overrides.orsAPIKey !== undefined ? overrides.orsAPIKey : ors,
    orgs: overrides.orgs ?? loadOrgsFromEnvOrFile(),
    trustProxy:
      overrides.trustProxy ??
      (process.env.TRUST_PROXY === '1' || process.env.TRUST_PROXY === 'true'),
  }
}

/** Finds an org by bearer token. */
export function findOrgByToken(config: GatewayConfig, token: string): OrgConfig | undefined {
  return config.orgs.find((org) => org.bearerToken === token)
}
