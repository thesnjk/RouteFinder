/** Organisation tenant from gateway config. */
export interface OrgConfig {
  id: string
  name: string
  bearerToken: string
  routeDailyCap?: number
  geocodeDailyCap?: number
}

/** Gateway runtime configuration. */
export interface GatewayConfig {
  port: number
  dataDir: string
  orsAPIKey: string | null
  orgs: OrgConfig[]
  trustProxy: boolean
}

export interface FleetOrg {
  id: string
  name: string
}

export interface FleetVehicle {
  id: string
  orgId: string
  label: string
  registrationPlate?: string | null
  profile?: Record<string, unknown> | null
}

export interface FleetTripStop {
  id: string
  sequence: number
  label: string
  latitude: number
  longitude: number
  role: string
}

export interface FleetTrip {
  id: string
  orgId: string
  vehicleId: string
  status: string
  stops: FleetTripStop[]
  vehicleProfile?: Record<string, unknown> | null
  physicsETASeconds?: number | null
  predictiveReport?: unknown
  companyBreaks?: unknown[]
  predictedLayby?: unknown
  latestInspectionSummary?: unknown
  inspectionReportPDFBase64?: string | null
  driverLatitude?: number | null
  driverLongitude?: number | null
  driverLocationRecordedAt?: string | null
  updatedAt: string
}

export interface FleetTripSnapshot {
  tripId: string
  status: string
  orderedStopIds: string[]
  physicsETASeconds?: number | null
  predictiveReport?: unknown
  predictedLayby?: unknown
  latestInspectionSummary?: unknown
  inspectionReportPDFBase64?: string | null
  driverLatitude?: number | null
  driverLongitude?: number | null
  driverLocationRecordedAt?: string | null
  updatedAt?: string
}

export interface FleetDispatchEvent {
  kind: 'tripPushed' | 'heartbeat'
  vehicleId: string
  tripId: string | null
  timestamp: string
}

export interface FleetProxyStatusResponse {
  orsConfigured: boolean
  routesToday: number
  routeDailyCap: number
  geocodeToday: number
  geocodeDailyCap: number
}

export interface CreateOrgRequest {
  name: string
}

declare module 'hono' {
  interface ContextVariableMap {
    org: OrgConfig
  }
}
