import { mkdirSync, readFileSync, writeFileSync, existsSync, renameSync } from 'node:fs'
import { join } from 'node:path'
import type { FleetProxyStatusResponse, OrgConfig } from '../types.js'

type Provider = 'orsRoute' | 'orsGeocode'

interface MeterSnapshot {
  dayStamp: string
  routeCount: number
  geocodeCount: number
}

function dayKey(date = new Date()): string {
  return `${date.getFullYear()}-${date.getMonth() + 1}-${date.getDate()}`
}

/** Per-org calendar-day ORS proxy metering persisted to disk. */
export class OrgProxyMeter {
  private readonly filePath: string
  private dayStamp: string
  private routeCount = 0
  private geocodeCount = 0
  private readonly routeDailyCap: number
  private readonly geocodeDailyCap: number

  constructor(dataDir: string, org: OrgConfig) {
    const dir = join(dataDir, org.id)
    mkdirSync(dir, { recursive: true })
    this.filePath = join(dir, 'proxy-meter.json')
    this.routeDailyCap = org.routeDailyCap ?? 2000
    this.geocodeDailyCap = org.geocodeDailyCap ?? 2000
    this.dayStamp = dayKey()
    this.load()
  }

  private load(): void {
    if (!existsSync(this.filePath)) return
    try {
      const raw = JSON.parse(readFileSync(this.filePath, 'utf8')) as MeterSnapshot
      this.dayStamp = raw.dayStamp || dayKey()
      this.routeCount = raw.routeCount ?? 0
      this.geocodeCount = raw.geocodeCount ?? 0
      this.rolloverIfNeeded()
    } catch {
      // Corrupt meter file: start fresh for the day.
      this.dayStamp = dayKey()
      this.routeCount = 0
      this.geocodeCount = 0
    }
  }

  private persist(): void {
    const snapshot: MeterSnapshot = {
      dayStamp: this.dayStamp,
      routeCount: this.routeCount,
      geocodeCount: this.geocodeCount,
    }
    const tmp = `${this.filePath}.${process.pid}.tmp`
    writeFileSync(tmp, JSON.stringify(snapshot, null, 2), 'utf8')
    renameSync(tmp, this.filePath)
  }

  private rolloverIfNeeded(): void {
    const today = dayKey()
    if (today === this.dayStamp) return
    this.dayStamp = today
    this.routeCount = 0
    this.geocodeCount = 0
    this.persist()
  }

  allows(provider: Provider): boolean {
    this.rolloverIfNeeded()
    if (provider === 'orsRoute') return this.routeCount < this.routeDailyCap
    return this.geocodeCount < this.geocodeDailyCap
  }

  record(provider: Provider): void {
    this.rolloverIfNeeded()
    if (provider === 'orsRoute') this.routeCount += 1
    else this.geocodeCount += 1
    this.persist()
  }

  status(orsConfigured: boolean): FleetProxyStatusResponse {
    this.rolloverIfNeeded()
    return {
      orsConfigured,
      routesToday: this.routeCount,
      routeDailyCap: this.routeDailyCap,
      geocodeToday: this.geocodeCount,
      geocodeDailyCap: this.geocodeDailyCap,
    }
  }
}

/** Caches meters per org. */
export class MeterRegistry {
  private readonly meters = new Map<string, OrgProxyMeter>()

  constructor(private readonly dataDir: string) {}

  forOrg(org: OrgConfig): OrgProxyMeter {
    let meter = this.meters.get(org.id)
    if (!meter) {
      meter = new OrgProxyMeter(this.dataDir, org)
      this.meters.set(org.id, meter)
    }
    return meter
  }

  /** Drop cached meter so the next lookup reloads from disk (tests). */
  forget(orgId: string): void {
    this.meters.delete(orgId)
  }
}
