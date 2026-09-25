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

export interface StopTimeWindow {
  stopId: string
  earliestArrival?: string | null
  latestArrival?: string | null
}

export interface FleetJobBrief {
  grossWeightKg?: number | null
  adrClass?: string | null
  /** Optional per-stop time windows (ISO timestamps). */
  timeWindows?: StopTimeWindow[]
  autoFindRoute?: boolean
  autoRehearse?: boolean
}

/** Compact walkaround summary from driver snapshot (mirrors Swift TripBriefInspectionSummary). */
export interface TripBriefInspectionSummary {
  vehicleLabel: string
  registrationPlate?: string | null
  defectCount: number
  /** ISO-8601 timestamp when the walkaround was completed. */
  completedAt: string
}

export interface FleetTrip {
  id: string
  orgId: string
  vehicleId: string
  status: FleetTripStatus
  stops: FleetTripStop[]
  physicsETASeconds?: number | null
  updatedAt: string
  latestInspectionSummary?: TripBriefInspectionSummary | null
  /** Base64-encoded walkaround PDF from driver snapshot (optional). */
  inspectionReportPDFBase64?: string | null
  /** Optional dispatch job brief (weight / ADR / auto-intake). */
  jobBrief?: FleetJobBrief | null
  /** Latest driver latitude from snapshot (WGS84). */
  driverLatitude?: number | null
  /** Latest driver longitude from snapshot (WGS84). */
  driverLongitude?: number | null
  /** ISO timestamp when driver location was recorded. */
  driverLocationRecordedAt?: string | null
}

export interface FleetServerHealth {
  ok: boolean
  version: string
}

/** Operator-paid proxy metering from GET /v1/proxy/status */
export interface FleetProxyStatus {
  orsConfigured: boolean
  routesToday: number
  routeDailyCap: number
  geocodeToday: number
  geocodeDailyCap: number
  /** Optional — present when fleet server reports forecast proxy keys (U14). */
  tomTomConfigured?: boolean
  openWeatherConfigured?: boolean
  tomTomToday?: number
  tomTomDailyCap?: number
  openWeatherToday?: number
  openWeatherDailyCap?: number
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

/** Single Pelias geocode suggestion from fleet proxy. */
export interface GeocodeSuggestion {
  label: string
  latitude: number
  longitude: number
}

/** Build Pelias proxy search URL (no api_key — fleet server injects operator key). */
export function geocodeSearchUrl(
  baseUrl: string,
  text: string,
  options?: { size?: number; focusLat?: number; focusLon?: number },
): string {
  const params = new URLSearchParams({
    text,
    size: String(options?.size ?? 8),
    'boundary.country': 'GBR',
  })
  const focusLat = options?.focusLat ?? 52.6309
  const focusLon = options?.focusLon ?? 1.2974
  params.set('focus.point.lat', String(focusLat))
  params.set('focus.point.lon', String(focusLon))
  return `${joinUrl(baseUrl, '/v1/proxy/pelias/v1/search')}?${params.toString()}`
}
