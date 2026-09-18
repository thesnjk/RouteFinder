import { mkdirSync, readFileSync, writeFileSync, existsSync, renameSync } from 'node:fs'
import { join } from 'node:path'
import { randomUUID } from 'node:crypto'
import type {
  FleetOrg,
  FleetTrip,
  FleetTripSnapshot,
  FleetVehicle,
  OrgConfig,
} from '../types.js'

interface StoreSnapshot {
  orgs: FleetOrg[]
  vehicles: FleetVehicle[]
  trips: FleetTrip[]
  activeTripByVehicle: Record<string, string>
}

/** Disk-backed fleet store scoped to one org tenant (DiskFleetStore-compatible). */
export class OrgFleetStore {
  private readonly directory: string
  private readonly filePath: string
  private orgById = new Map<string, FleetOrg>()
  private vehicleById = new Map<string, FleetVehicle>()
  private tripById = new Map<string, FleetTrip>()
  private activeTripByVehicle = new Map<string, string>()
  private loaded = false

  constructor(dataDir: string, private readonly orgConfig: OrgConfig) {
    this.directory = join(dataDir, orgConfig.id)
    this.filePath = join(this.directory, 'fleet-store.json')
    mkdirSync(this.directory, { recursive: true })
  }

  private ensureLoaded(): void {
    if (this.loaded) return
    this.loaded = true
    if (existsSync(this.filePath)) {
      const snapshot = JSON.parse(readFileSync(this.filePath, 'utf8')) as StoreSnapshot
      for (const org of snapshot.orgs ?? []) this.orgById.set(org.id, org)
      for (const vehicle of snapshot.vehicles ?? []) this.vehicleById.set(vehicle.id, vehicle)
      for (const trip of snapshot.trips ?? []) this.tripById.set(trip.id, trip)
      for (const [vehicleId, tripId] of Object.entries(snapshot.activeTripByVehicle ?? {})) {
        this.activeTripByVehicle.set(vehicleId, tripId)
      }
    }
    if (!this.orgById.has(this.orgConfig.id)) {
      this.orgById.set(this.orgConfig.id, {
        id: this.orgConfig.id,
        name: this.orgConfig.name,
      })
      this.persist()
    }
  }

  private persist(): void {
    const snapshot: StoreSnapshot = {
      orgs: [...this.orgById.values()],
      vehicles: [...this.vehicleById.values()],
      trips: [...this.tripById.values()],
      activeTripByVehicle: Object.fromEntries(this.activeTripByVehicle),
    }
    const tmp = `${this.filePath}.${process.pid}.tmp`
    writeFileSync(tmp, JSON.stringify(snapshot, null, 2), 'utf8')
    renameSync(tmp, this.filePath)
  }

  createOrg(name: string): FleetOrg {
    this.ensureLoaded()
    const org: FleetOrg = { id: randomUUID(), name }
    this.orgById.set(org.id, org)
    this.persist()
    return org
  }

  orgs(): FleetOrg[] {
    this.ensureLoaded()
    return [...this.orgById.values()].sort((a, b) => a.name.localeCompare(b.name))
  }

  registerVehicle(vehicle: FleetVehicle): FleetVehicle {
    this.ensureLoaded()
    const stored: FleetVehicle = {
      ...vehicle,
      id: vehicle.id || randomUUID(),
    }
    this.vehicleById.set(stored.id, stored)
    this.persist()
    return stored
  }

  vehicles(forOrgId: string): FleetVehicle[] {
    this.ensureLoaded()
    return [...this.vehicleById.values()]
      .filter((v) => v.orgId === forOrgId)
      .sort((a, b) => a.label.localeCompare(b.label))
  }

  pushTrip(trip: FleetTrip): FleetTrip {
    this.ensureLoaded()
    const pushed: FleetTrip = {
      ...trip,
      id: trip.id || randomUUID(),
      status: 'dispatched',
      updatedAt: new Date().toISOString(),
      companyBreaks: trip.companyBreaks ?? [],
    }
    this.tripById.set(pushed.id, pushed)
    this.activeTripByVehicle.set(pushed.vehicleId, pushed.id)
    this.persist()
    return pushed
  }

  activeTrip(vehicleId: string): FleetTrip | null {
    this.ensureLoaded()
    const tripId = this.activeTripByVehicle.get(vehicleId)
    if (!tripId) return null
    return this.tripById.get(tripId) ?? null
  }

  trip(id: string): FleetTrip | null {
    this.ensureLoaded()
    return this.tripById.get(id) ?? null
  }

  applySnapshot(snapshot: FleetTripSnapshot): FleetTrip {
    this.ensureLoaded()
    const existing = this.tripById.get(snapshot.tripId)
    if (!existing) {
      throw new Error('tripNotFound')
    }
    const byId = new Map(existing.stops.map((s) => [s.id, { ...s }]))
    const reordered = []
    for (let index = 0; index < snapshot.orderedStopIds.length; index++) {
      const stopId = snapshot.orderedStopIds[index]
      const stop = byId.get(stopId)
      if (!stop) continue
      stop.sequence = index
      reordered.push(stop)
    }
    const updated: FleetTrip = {
      ...existing,
      status: snapshot.status,
      stops: reordered.length === snapshot.orderedStopIds.length ? reordered : existing.stops,
      physicsETASeconds: snapshot.physicsETASeconds ?? existing.physicsETASeconds,
      predictiveReport: snapshot.predictiveReport ?? existing.predictiveReport,
      predictedLayby: snapshot.predictedLayby ?? existing.predictedLayby,
      latestInspectionSummary:
        snapshot.latestInspectionSummary ?? existing.latestInspectionSummary,
      inspectionReportPDFBase64:
        snapshot.inspectionReportPDFBase64 ?? existing.inspectionReportPDFBase64,
      driverLatitude: snapshot.driverLatitude ?? existing.driverLatitude,
      driverLongitude: snapshot.driverLongitude ?? existing.driverLongitude,
      driverLocationRecordedAt:
        snapshot.driverLocationRecordedAt ?? existing.driverLocationRecordedAt,
      updatedAt: snapshot.updatedAt ?? new Date().toISOString(),
    }
    this.tripById.set(updated.id, updated)
    this.persist()
    return updated
  }

  ingestTelematics(body: {
    vehicleId: string
    latitude: number
    longitude: number
    recordedAt?: string
    provider?: string | null
    vehicleLabel?: string | null
  }): Record<string, unknown> {
    this.ensureLoaded()
    const telematicsPath = join(this.directory, 'telematics-pings.json')
    let pings: Record<string, unknown>[] = []
    if (existsSync(telematicsPath)) {
      try {
        pings = JSON.parse(readFileSync(telematicsPath, 'utf8')) as Record<string, unknown>[]
      } catch {
        pings = []
      }
    }
    const rawProvider = (body.provider ?? '').toLowerCase()
    let provider = 'unknown'
    if (rawProvider.includes('geotab')) provider = 'geotab'
    else if (rawProvider.includes('samsara')) provider = 'samsara'
    const label =
      (body.vehicleLabel ?? '').trim() || body.vehicleId
    const ping = {
      provider,
      vehicleLabel: label,
      latitude: body.latitude,
      longitude: body.longitude,
      recordedAt: body.recordedAt ?? new Date().toISOString(),
      speedKph: null,
    }
    pings.push(ping)
    if (pings.length > 200) pings = pings.slice(-200)
    const tmp = `${telematicsPath}.${process.pid}.tmp`
    writeFileSync(tmp, JSON.stringify(pings, null, 2), 'utf8')
    renameSync(tmp, telematicsPath)
    return ping
  }
}

/** Factory that caches stores per org id. */
export class StoreRegistry {
  private readonly stores = new Map<string, OrgFleetStore>()

  constructor(private readonly dataDir: string) {
    mkdirSync(dataDir, { recursive: true })
  }

  forOrg(org: OrgConfig): OrgFleetStore {
    let store = this.stores.get(org.id)
    if (!store) {
      store = new OrgFleetStore(this.dataDir, org)
      this.stores.set(org.id, store)
    }
    return store
  }
}
