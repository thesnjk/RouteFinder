import {
  authHeaders,
  joinUrl,
  type FleetConnection,
  type FleetOrg,
  type FleetServerHealth,
  type FleetTrip,
  type FleetTripStop,
  type FleetVehicle,
} from './types'

async function parseJson<T>(response: Response): Promise<T> {
  if (!response.ok) {
    const text = await response.text()
    throw new Error(`${response.status} ${response.statusText}: ${text.slice(0, 200)}`)
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

  /** Build a minimal two-stop dispatched trip for LAN demos. */
  buildDemoTrip(orgId: string, vehicleId: string, originLabel: string, destLabel: string): FleetTrip {
    const origin: FleetTripStop = {
      id: crypto.randomUUID(),
      sequence: 0,
      label: originLabel,
      latitude: 53.4808,
      longitude: -2.2426,
      role: 'origin',
    }
    const destination: FleetTripStop = {
      id: crypto.randomUUID(),
      sequence: 1,
      label: destLabel,
      latitude: 53.4084,
      longitude: -2.9916,
      role: 'destination',
    }
    return {
      id: crypto.randomUUID(),
      orgId,
      vehicleId,
      status: 'dispatched',
      stops: [origin, destination],
      updatedAt: new Date().toISOString(),
    }
  }
}
