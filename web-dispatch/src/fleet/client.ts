import {
  authHeaders,
  geocodeSearchUrl,
  joinUrl,
  type FleetConnection,
  type FleetJobBrief,
  type FleetOrg,
  type FleetProxyStatus,
  type FleetServerHealth,
  type FleetTrip,
  type FleetTripStop,
  type FleetVehicle,
  type GeocodeSuggestion,
} from './types'
import { fleetProxyUserMessage, type FleetProxyErrorKind } from '../fleetProxyError'
import {
  buildOrsHgvDirectionsBody,
  parseOrsGeoJsonCoordinates,
  type HgvPreviewProfile,
  type LngLat,
} from '../orsRoutePreview'
import { KINGS_LYNN, NORWICH } from '../demoCorridor'

export { parseOrsGeoJsonCoordinates, buildOrsHgvDirectionsBody }
export type { HgvPreviewProfile, LngLat }

interface PeliasFeatureCollection {
  features?: Array<{
    geometry?: { coordinates?: [number, number] }
    properties?: { label?: string; name?: string }
  }>
}

async function parseJson<T>(
  response: Response,
  kind: FleetProxyErrorKind = 'generic',
): Promise<T> {
  if (!response.ok) {
    const text = await response.text()
    throw new Error(fleetProxyUserMessage(response.status, text, kind))
  }
  return (await response.json()) as T
}

/** Thin HTTP client for RouteFinderFleetServer REST surface. */
export class FleetApiClient {
  private readonly connection: FleetConnection

  constructor(connection: FleetConnection) {
    this.connection = connection
  }

  private url(path: string): string {
    return joinUrl(this.connection.baseUrl, path)
  }

  private headers(): HeadersInit {
    return authHeaders(this.connection.apiKey)
  }

  async health(): Promise<FleetServerHealth> {
    const response = await fetch(this.url('/health'), { headers: this.headers() })
    return parseJson(response)
  }

  async proxyStatus(): Promise<FleetProxyStatus> {
    const response = await fetch(this.url('/v1/proxy/status'), { headers: this.headers() })
    return parseJson(response)
  }

  async listOrgs(): Promise<FleetOrg[]> {
    const response = await fetch(this.url('/v1/orgs'), { headers: this.headers() })
    return parseJson(response)
  }

  async createOrg(name: string): Promise<FleetOrg> {
    const response = await fetch(this.url('/v1/orgs'), {
      method: 'POST',
      headers: this.headers(),
      body: JSON.stringify({ name }),
    })
    return parseJson(response)
  }

  async listVehicles(orgId: string): Promise<FleetVehicle[]> {
    const response = await fetch(this.url(`/v1/orgs/${orgId}/vehicles`), {
      headers: this.headers(),
    })
    return parseJson(response)
  }

  async registerVehicle(vehicle: Omit<FleetVehicle, 'id'> & { id?: string }): Promise<FleetVehicle> {
    const body = {
      id: vehicle.id ?? crypto.randomUUID(),
      orgId: vehicle.orgId,
      label: vehicle.label,
      registrationPlate: vehicle.registrationPlate ?? null,
    }
    const response = await fetch(this.url('/v1/vehicles'), {
      method: 'POST',
      headers: this.headers(),
      body: JSON.stringify(body),
    })
    return parseJson(response)
  }

  async pushTrip(trip: FleetTrip): Promise<FleetTrip> {
    const response = await fetch(this.url('/v1/trips'), {
      method: 'POST',
      headers: this.headers(),
      body: JSON.stringify(trip),
    })
    return parseJson(response)
  }

  async getTrip(tripId: string): Promise<FleetTrip> {
    const response = await fetch(this.url(`/v1/trips/${tripId}`), { headers: this.headers() })
    return parseJson(response)
  }

  async activeTrip(vehicleId: string): Promise<FleetTrip | null> {
    const response = await fetch(this.url(`/v1/vehicles/${vehicleId}/active-trip`), {
      headers: this.headers(),
    })
    if (response.status === 204) return null
    return parseJson(response)
  }

  /**
   * Search UK addresses via fleet Pelias proxy (`GET /v1/proxy/pelias/v1/search`).
   * Requires fleet server started with `--ors-key`.
   */
  async geocodeSearch(
    text: string,
    options?: { size?: number; focusLat?: number; focusLon?: number },
  ): Promise<GeocodeSuggestion[]> {
    const trimmed = text.trim()
    if (trimmed.length < 2) return []
    const url = geocodeSearchUrl(this.connection.baseUrl, trimmed, options)
    const response = await fetch(url, { headers: this.headers() })
    const collection = await parseJson<PeliasFeatureCollection>(response, 'geocode')
    const suggestions: GeocodeSuggestion[] = []
    for (const feature of collection.features ?? []) {
      const coords = feature.geometry?.coordinates
      if (!coords || coords.length < 2) continue
      const [lon, lat] = coords
      const label = feature.properties?.label ?? feature.properties?.name
      if (!label) continue
      suggestions.push({ label, latitude: lat, longitude: lon })
    }
    return suggestions
  }

  /**
   * HGV corridor via fleet ORS proxy (`POST …/directions/driving-hgv/geojson`).
   * Returns empty array on parse failure; throws on HTTP errors (incl. 429 cap copy).
   */
  async routePreviewHGV(
    stops: Array<{ longitude: number; latitude: number }>,
    profile?: HgvPreviewProfile | null,
  ): Promise<LngLat[]> {
    if (stops.length < 2) return []
    const response = await fetch(
      this.url('/v1/proxy/ors/v2/directions/driving-hgv/geojson'),
      {
        method: 'POST',
        headers: this.headers(),
        body: JSON.stringify(buildOrsHgvDirectionsBody(stops, profile)),
      },
    )
    const payload = await parseJson<unknown>(response, 'route')
    return parseOrsGeoJsonCoordinates(payload)
  }

  /** Build a two-stop trip from geocoded stop coordinates. */
  buildTripFromStops(
    orgId: string,
    vehicleId: string,
    origin: { label: string; latitude: number; longitude: number; id?: string },
    destination: { label: string; latitude: number; longitude: number; id?: string },
    jobBrief?: FleetJobBrief | null,
  ): FleetTrip {
    const originStop: FleetTripStop = {
      id: origin.id ?? crypto.randomUUID(),
      sequence: 0,
      label: origin.label,
      latitude: origin.latitude,
      longitude: origin.longitude,
      role: 'origin',
    }
    const destStop: FleetTripStop = {
      id: destination.id ?? crypto.randomUUID(),
      sequence: 1,
      label: destination.label,
      latitude: destination.latitude,
      longitude: destination.longitude,
      role: 'destination',
    }
    return {
      id: crypto.randomUUID(),
      orgId,
      vehicleId,
      status: 'dispatched',
      stops: [originStop, destStop],
      updatedAt: new Date().toISOString(),
      ...(jobBrief ? { jobBrief } : {}),
    }
  }

  /** @deprecated Prefer buildTripFromStops with geocoded coordinates. */
  buildDemoTrip(orgId: string, vehicleId: string, originLabel: string, destLabel: string): FleetTrip {
    return this.buildTripFromStops(
      orgId,
      vehicleId,
      { label: originLabel, latitude: NORWICH.latitude, longitude: NORWICH.longitude },
      { label: destLabel, latitude: KINGS_LYNN.latitude, longitude: KINGS_LYNN.longitude },
    )
  }
}
