/** Fleet API types mirroring RouteFinder Contracts/Fleet (JSON). */

export type FleetTripStatus =
  | 'draft'
  | 'dispatched'
  | 'accepted'
  | 'optimized'
  | 'rehearsed'
  | 'active'
  | 'completed'

export interface FleetOrg {
  id: string
  name: string
}

export interface FleetVehicle {
  id: string
  orgId: string
  label: string
  registrationPlate?: string | null
}

export interface FleetTripStop {
  id: string
  sequence: number
  label: string
  latitude: number
  longitude: number
  role: 'origin' | 'via' | 'destination'
}

export interface FleetTrip {
  id: string
  orgId: string
  vehicleId: string
  status: FleetTripStatus
  stops: FleetTripStop[]
  physicsETASeconds?: number | null
  updatedAt: string
  latestInspectionSummary?: unknown
}

export interface FleetServerHealth {
  ok: boolean
  version: string
}

/** Operator-paid ORS proxy metering from GET /v1/proxy/status */
export interface FleetProxyStatus {
  orsConfigured: boolean
  routesToday: number
  routeDailyCap: number
  geocodeToday: number
  geocodeDailyCap: number
}

export interface FleetConnection {
  /** Base URL of RouteFinderFleetServer, e.g. http://192.168.1.10:8080 */
  baseUrl: string
  /** Optional API key when server started with --api-key */
  apiKey: string
}

export function authHeaders(apiKey: string): HeadersInit {
  if (!apiKey.trim()) return { Accept: 'application/json', 'Content-Type': 'application/json' }
  return {
    Accept: 'application/json',
    'Content-Type': 'application/json',
    Authorization: `Bearer ${apiKey.trim()}`,
  }
}

export function joinUrl(baseUrl: string, path: string): string {
  const base = baseUrl.replace(/\/$/, '')
  const suffix = path.startsWith('/') ? path : `/${path}`
  return `${base}${suffix}`
}
