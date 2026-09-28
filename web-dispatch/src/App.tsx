import { useCallback, useEffect, useMemo, useRef, useState } from 'react'
import './App.css'
import { FleetApiClient } from './fleet/client'
import type {
  FleetOrg,
  FleetProxyStatus,
  FleetTrip,
  FleetVehicle,
  TripBriefInspectionSummary,
} from './fleet/types'
import { GeocodeSearchField, type GeocodedStop } from './GeocodeSearchField'
import {
  downloadInspectionPdf,
  inspectionHasDefects,
  inspectionSummaryLine,
  inspectionToastMessage,
  shouldAnnounceInspection,
} from './inspectionSummary'
import { fleetProxyUserMessage } from './fleetProxyError'
import { fleetHealthLabel } from './fleetHealthLabel'
import { canPushTrip, isPushBlockedByFleetHealth } from './dispatchPushGate'
import { TripMapPreview } from './TripMapPreview'
import { VehicleQR } from './VehicleQR'
import { filterVehicles } from './vehicleFilter'
import {
  ROSTER_VEHICLE_CAP,
  buildRosterRows,
  formatGpsAge,
  formatPhysicsEta,
  rosterDriverPins,
  type FleetVehicleStatus,
} from './fleetRoster'

const STORAGE_KEY = 'routefinder.webDispatch.connection'
const ONBOARDING_KEY = 'routefinder.webDispatch.onboardingDone'
/** Dev default: Vite proxy avoids CORS. Direct :8080 works once fleet CORS is enabled. */
const DEFAULT_BASE_URL = '/fleet'

function loadConnection(): { baseUrl: string; apiKey: string } {
  try {
    const raw = localStorage.getItem(STORAGE_KEY)
    if (raw) {
      const parsed = JSON.parse(raw) as { baseUrl: string; apiKey: string }
      if (parsed.baseUrl === 'http://127.0.0.1:8080' || parsed.baseUrl === 'http://localhost:8080') {
        return { baseUrl: DEFAULT_BASE_URL, apiKey: parsed.apiKey ?? '' }
      }
      return parsed
    }
  } catch {
    /* ignore */
  }
  return { baseUrl: DEFAULT_BASE_URL, apiKey: '' }
}

export default function App() {
  const [baseUrl, setBaseUrl] = useState(() => loadConnection().baseUrl)
  const [apiKey, setApiKey] = useState(() => loadConnection().apiKey)
  const [health, setHealth] = useState<string>('Not checked')
  const [healthOk, setHealthOk] = useState(false)
  const [proxyStatus, setProxyStatus] = useState<FleetProxyStatus | null>(null)
  const [orgs, setOrgs] = useState<FleetOrg[]>([])
  const [vehicles, setVehicles] = useState<FleetVehicle[]>([])
  const [orgId, setOrgId] = useState('')
  const [vehicleId, setVehicleId] = useState('')
  const [vehicleFilterQuery, setVehicleFilterQuery] = useState('')
  const [newOrgName, setNewOrgName] = useState('Pilot fleet')
  const [newVehicleLabel, setNewVehicleLabel] = useState('Unit 1')
  const [originStop, setOriginStop] = useState<GeocodedStop | null>(null)
  const [destStop, setDestStop] = useState<GeocodedStop | null>(null)
  const [grossWeightKg, setGrossWeightKg] = useState('')
  const [adrClass, setAdrClass] = useState('')
  const [originEarliest, setOriginEarliest] = useState('')
  const [originLatest, setOriginLatest] = useState('')
  const [destEarliest, setDestEarliest] = useState('')
  const [destLatest, setDestLatest] = useState('')
  const [lastTrip, setLastTrip] = useState<FleetTrip | null>(null)
  const [liveTrip, setLiveTrip] = useState<FleetTrip | null>(null)
  const [rosterRows, setRosterRows] = useState<FleetVehicleStatus[]>([])
  const [rosterError, setRosterError] = useState<string | null>(null)
  const [inspectionToast, setInspectionToast] = useState<string | null>(null)
  const [error, setError] = useState<string | null>(null)
  const [busy, setBusy] = useState(false)
  const previousInspectionRef = useRef<TripBriefInspectionSummary | null>(null)
  const lastAnnouncedInspectionRef = useRef<TripBriefInspectionSummary | null>(null)
  const [showOnboarding, setShowOnboarding] = useState(
    () => localStorage.getItem(ONBOARDING_KEY) !== '1',
  )
  const [tourStep, setTourStep] = useState(0)

  const client = useMemo(
    () => new FleetApiClient({ baseUrl, apiKey }),
    [baseUrl, apiKey],
  )

  const persist = useCallback(() => {
    localStorage.setItem(STORAGE_KEY, JSON.stringify({ baseUrl, apiKey }))
  }, [baseUrl, apiKey])

  const run = useCallback(
    async (action: () => Promise<void>) => {
      setBusy(true)
      setError(null)
      try {
        await action()
      } catch (err) {
        setError(err instanceof Error ? err.message : String(err))
      } finally {
        setBusy(false)
      }
    },
    [],
  )

  const refreshHealth = useCallback(async () => {
    persist()
    try {
      const h = await client.health()
      if (!h.ok) {
        setHealthOk(false)
        setHealth(fleetHealthLabel({ healthOk: false, authSucceeded: false }))
        setProxyStatus(null)
        return
      }
      try {
        setProxyStatus(await client.proxyStatus())
        setHealthOk(true)
        setHealth(
          fleetHealthLabel({
            healthOk: true,
            authSucceeded: true,
            version: h.version,
          }),
        )
      } catch (err) {
        setProxyStatus(null)
        setHealthOk(false)
        const message = err instanceof Error ? err.message : String(err)
        setHealth(
          fleetHealthLabel({
            healthOk: true,
            authSucceeded: false,
            errorMessage: message,
          }),
        )
      }
    } catch (err) {
      setHealthOk(false)
      setHealth(
        fleetHealthLabel({
          healthOk: false,
          authSucceeded: false,
          errorMessage: err instanceof Error ? err.message : String(err),
        }),
      )
      setProxyStatus(null)
    }
  }, [client, persist])

  useEffect(() => {
    if (!vehicleId) {
      setLiveTrip(null)
      previousInspectionRef.current = null
      lastAnnouncedInspectionRef.current = null
      setInspectionToast(null)
      return
    }
    let cancelled = false
    const tick = async () => {
      try {
        const trip = await client.activeTrip(vehicleId)
        if (cancelled) return
        const newSummary = trip?.latestInspectionSummary ?? null
        if (
          shouldAnnounceInspection(
            previousInspectionRef.current,
            newSummary,
            lastAnnouncedInspectionRef.current,
          ) &&
          newSummary
        ) {
          setInspectionToast(inspectionToastMessage(newSummary))
          lastAnnouncedInspectionRef.current = newSummary
        }
        previousInspectionRef.current = newSummary
        setLiveTrip(trip)
        setError(null)
      } catch (err) {
        // Keep last good snapshot; surface LAN/key failures so desk does not look live.
        const message =
          err instanceof Error
            ? err.message
            : fleetProxyUserMessage(0, String(err), 'generic')
        setError(message)
      }
    }
    void tick()
    const id = window.setInterval(() => void tick(), 5000)
    return () => {
      cancelled = true
      window.clearInterval(id)
    }
  }, [client, vehicleId])

  const selectedVehicle = vehicles.find((v) => v.id === vehicleId)
  const filteredVehicles = useMemo(
    () => filterVehicles(vehicles, vehicleFilterQuery),
    [vehicles, vehicleFilterQuery],
  )
  const rosterVehicles = useMemo(
    () => filteredVehicles.slice(0, ROSTER_VEHICLE_CAP),
    [filteredVehicles],
  )

  const pushReady = useMemo(
    () =>
      canPushTrip({
        hasVehicle: Boolean(orgId && vehicleId),
        hasResolvedStops: Boolean(originStop && destStop),
        healthOk,
      }),
    [orgId, vehicleId, originStop, destStop, healthOk],
  )
  const pushBlockedByHealth = useMemo(
    () =>
      isPushBlockedByFleetHealth({
        hasVehicle: Boolean(orgId && vehicleId),
        hasResolvedStops: Boolean(originStop && destStop),
        healthOk,
      }),
    [orgId, vehicleId, originStop, destStop, healthOk],
  )

  useEffect(() => {
    if (!healthOk || rosterVehicles.length === 0) {
      setRosterRows([])
      setRosterError(null)
      return
    }
    let cancelled = false
    const tick = async () => {
      const results = await Promise.all(
        rosterVehicles.map(async (v) => {
          try {
            const trip = await client.activeTrip(v.id)
            return { id: v.id, trip, ok: true as const }
          } catch (err) {
            return {
              id: v.id,
              trip: null as FleetTrip | null,
              ok: false as const,
              message: err instanceof Error ? err.message : String(err),
            }
          }
        }),
      )
      if (cancelled) return
      const tripByVehicleId: Record<string, FleetTrip | null> = {}
      let failCount = 0
      let lastFailMessage = ''
      for (const r of results) {
        tripByVehicleId[r.id] = r.trip
        if (!r.ok) {
          failCount += 1
          lastFailMessage = r.message
        }
      }
      setRosterRows(buildRosterRows(rosterVehicles, tripByVehicleId, Date.now()))
      if (failCount === results.length && results.length > 0) {
        setRosterError(lastFailMessage || 'Fleet roster poll failed')
        setError(lastFailMessage || 'Fleet roster poll failed')
      } else {
        setRosterError(failCount > 0 ? `${failCount} vehicle(s) failed to refresh` : null)
      }
    }
    void tick()
    const id = window.setInterval(() => void tick(), 8000)
    return () => {
      cancelled = true
      window.clearInterval(id)
    }
  }, [client, healthOk, rosterVehicles])

  const snapshotTrip = liveTrip ?? lastTrip

  const finishOnboarding = () => {
    localStorage.setItem(ONBOARDING_KEY, '1')
    setShowOnboarding(false)
  }

  const tourCopy = [
    {
      title: 'Welcome to Web Dispatch',
      body: 'This browser console talks to RouteFinderFleetServer on your office LAN. Same Wi‑Fi as driver phones. Not a hosted cloud portal.',
    },
    {
      title: '1 · Connect',
      body: 'Use /fleet in local dev (Vite proxy) or http://<mac-ip>:8080 on the office network. Tap Test /health until it says Connected.',
    },
    {
      title: '2 · Org & vehicle',
      body: 'Create an organisation, register a vehicle, then show the QR to the driver (or copy the UUID into the iOS Fleet setup wizard).',
    },
    {
      title: '3 · Push trip',
      body: 'Push a demo Norwich → King\'s Lynn trip. The driver toast appears within ~5 seconds. Snapshot panel updates when the phone reports ETA / status.',
    },
    {
      title: '4 · Walkaround defects',
      body: 'When the driver saves a walkaround with defects, the Driver snapshot panel shows an orange defect card (and optional PDF download) — same LAN handoff as Mac Dispatch, no third-party portal.',
    },
  ]

  return (
    <div className="app">
      <header>
        <h1>RouteFinder Web Dispatch</h1>
        <p className="muted">
          LAN console for <code>RouteFinderFleetServer</code> — not a hosted SaaS portal.
        </p>
        <div className={`health-pill ${healthOk ? 'health-pill--ok' : 'health-pill--fail'}`}>{health}</div>
      </header>

      {showOnboarding ? (
        <section className="panel onboarding">
          <h2>{tourCopy[tourStep].title}</h2>
          <p>{tourCopy[tourStep].body}</p>
          <div className="row">
            {tourStep > 0 ? (
              <button type="button" onClick={() => setTourStep((s) => s - 1)}>
                Back
              </button>
            ) : null}
            {tourStep < tourCopy.length - 1 ? (
              <button type="button" onClick={() => setTourStep((s) => s + 1)}>
                Next
              </button>
            ) : (
              <button type="button" onClick={finishOnboarding}>
                Start dispatching
              </button>
            )}
            <button type="button" className="button-secondary" onClick={finishOnboarding}>
              Skip
            </button>
          </div>
        </section>
      ) : null}

      <section className="panel">
        <h2>Connection</h2>
        <label>
          Server base URL
          <input
            value={baseUrl}
            onChange={(e) => setBaseUrl(e.target.value)}
            placeholder="/fleet · http://192.168.1.10:8080 · https://fleet.yourdomain.com"
          />
        </label>
        <p className="muted">
          LAN fleet server, Vite proxy <code>/fleet</code>, or hosted gateway HTTPS URL. Use the org
          bearer token below for hosted — never paste the operator ORS key.
        </p>
        <label>
          API key / org bearer token
          <input
            value={apiKey}
            onChange={(e) => setApiKey(e.target.value)}
            placeholder="Bearer token (--api-key or hosted org token)"
          />
        </label>
        <div className="row">
          <button disabled={busy} onClick={() => run(refreshHealth)}>
            Test /health
          </button>
          <button
            type="button"
            className="button-secondary"
            onClick={() => {
              setShowOnboarding(true)
              setTourStep(0)
            }}
          >
            Show tour
          </button>
        </div>
        {proxyStatus ? (
          <>
            <p className="muted">
              ORS proxy:{' '}
              {proxyStatus.orsConfigured
                ? `on · ${proxyStatus.routesToday}/${proxyStatus.routeDailyCap} routes · ${proxyStatus.geocodeToday}/${proxyStatus.geocodeDailyCap} geocodes today`
                : 'off (start server with --ors-key for address search and driver routing)'}
            </p>
            <p className="muted">
              TomTom flow proxy:{' '}
              {proxyStatus.tomTomConfigured
                ? `on${proxyStatus.tomTomToday != null && proxyStatus.tomTomDailyCap != null ? ` · ${proxyStatus.tomTomToday}/${proxyStatus.tomTomDailyCap} today` : ''}`
                : 'off (optional TOMTOM_API_KEY / --tomtom-key)'}
              {' · '}
              OpenWeather forecast:{' '}
              {proxyStatus.openWeatherConfigured
                ? `on${proxyStatus.openWeatherToday != null && proxyStatus.openWeatherDailyCap != null ? ` · ${proxyStatus.openWeatherToday}/${proxyStatus.openWeatherDailyCap} today` : ''}`
                : 'off (optional OPENWEATHER_API_KEY / --openweather-key)'}
            </p>
          </>
        ) : null}
      </section>

      <section className="panel">
        <h2>Org & vehicle</h2>
        <div className="row">
          <input value={newOrgName} onChange={(e) => setNewOrgName(e.target.value)} />
          <button
            disabled={busy}
            onClick={() =>
              run(async () => {
                persist()
                const org = await client.createOrg(newOrgName.trim() || 'Pilot fleet')
                setOrgs(await client.listOrgs())
                setOrgId(org.id)
              })
            }
          >
            Create org
          </button>
          <button
            disabled={busy}
            onClick={() =>
              run(async () => {
                persist()
                const list = await client.listOrgs()
                setOrgs(list)
                if (list[0] && !orgId) setOrgId(list[0].id)
              })
            }
          >
            Refresh orgs
          </button>
        </div>
        <label>
          Org
          <select value={orgId} onChange={(e) => setOrgId(e.target.value)}>
            <option value="">Select…</option>
            {orgs.map((o) => (
              <option key={o.id} value={o.id}>
                {o.name} ({o.id.slice(0, 8)})
              </option>
            ))}
          </select>
        </label>
        <div className="row">
          <input value={newVehicleLabel} onChange={(e) => setNewVehicleLabel(e.target.value)} />
          <button
            disabled={busy || !orgId}
            onClick={() =>
              run(async () => {
                persist()
                const vehicle = await client.registerVehicle({
                  orgId,
                  label: newVehicleLabel.trim() || 'Unit 1',
                })
                setVehicles(await client.listVehicles(orgId))
                setVehicleId(vehicle.id)
              })
            }
          >
            Register vehicle
          </button>
          <button
            disabled={busy || !orgId}
            onClick={() =>
              run(async () => {
                persist()
                const list = await client.listVehicles(orgId)
                setVehicles(list)
                if (list[0] && !vehicleId) setVehicleId(list[0].id)
              })
            }
          >
            Refresh vehicles
          </button>
        </div>
        <label>
          Filter vehicles
          <input
            type="search"
            value={vehicleFilterQuery}
            onChange={(e) => setVehicleFilterQuery(e.target.value)}
            placeholder="Label or plate…"
            disabled={busy || vehicles.length === 0}
            autoComplete="off"
          />
        </label>
        <label>
          Vehicle
          <select value={vehicleId} onChange={(e) => setVehicleId(e.target.value)}>
            <option value="">Select…</option>
            {filteredVehicles.map((v) => (
              <option key={v.id} value={v.id}>
                {v.label}
                {v.registrationPlate ? ` · ${v.registrationPlate}` : ''} ({v.id.slice(0, 8)})
              </option>
            ))}
            {vehicleId &&
            selectedVehicle &&
            !filteredVehicles.some((v) => v.id === vehicleId) ? (
              <option value={vehicleId}>
                {selectedVehicle.label} (filtered out — clear filter to browse)
              </option>
            ) : null}
          </select>
        </label>
        {vehicleId && selectedVehicle ? (
          <VehicleQR vehicleId={vehicleId} label={selectedVehicle.label} />
        ) : null}
      </section>

      <section className="panel">
        <h2>Push trip</h2>
        <GeocodeSearchField
          label="Origin"
          client={client}
          value={originStop}
          onChange={setOriginStop}
          placeholder="Search UK address…"
          disabled={busy}
        />
        <GeocodeSearchField
          label="Destination"
          client={client}
          value={destStop}
          onChange={setDestStop}
          placeholder="Search UK address…"
          disabled={busy}
        />
        <p className="muted">
          Address search uses the fleet Pelias proxy (requires server <code>--ors-key</code>). Pick a
          suggestion so lat/lon are set before push.
        </p>
        <label>
          Gross weight (kg)
          <input
            value={grossWeightKg}
            onChange={(e) => setGrossWeightKg(e.target.value)}
            placeholder="44000"
            disabled={busy}
          />
        </label>
        <label>
          ADR class
          <input
            value={adrClass}
            onChange={(e) => setAdrClass(e.target.value)}
            placeholder="3"
            disabled={busy}
          />
        </label>
        <p className="muted">Optional stop time windows (local datetime → ISO on push).</p>
        <label>
          Origin earliest
          <input
            type="datetime-local"
            value={originEarliest}
            onChange={(e) => setOriginEarliest(e.target.value)}
            disabled={busy}
          />
        </label>
        <label>
          Origin latest
          <input
            type="datetime-local"
            value={originLatest}
            onChange={(e) => setOriginLatest(e.target.value)}
            disabled={busy}
          />
        </label>
        <label>
          Destination earliest
          <input
            type="datetime-local"
            value={destEarliest}
            onChange={(e) => setDestEarliest(e.target.value)}
            disabled={busy}
          />
        </label>
        <label>
          Destination latest
          <input
            type="datetime-local"
            value={destLatest}
            onChange={(e) => setDestLatest(e.target.value)}
            disabled={busy}
          />
        </label>
        <button
          disabled={busy || !pushReady}
          onClick={() =>
            run(async () => {
              persist()
              if (!originStop || !destStop) return
              if (!healthOk) {
                throw new Error(
                  'Connect to the fleet server — health pill must show Connected before push.',
                )
              }
              const kg = Number.parseFloat(grossWeightKg)
              const originId = crypto.randomUUID()
              const destId = crypto.randomUUID()
              const timeWindows = [
                ...(originEarliest || originLatest
                  ? [
                      {
                        stopId: originId,
                        earliestArrival: originEarliest
                          ? new Date(originEarliest).toISOString()
                          : null,
                        latestArrival: originLatest ? new Date(originLatest).toISOString() : null,
                      },
                    ]
                  : []),
                ...(destEarliest || destLatest
                  ? [
                      {
                        stopId: destId,
                        earliestArrival: destEarliest ? new Date(destEarliest).toISOString() : null,
                        latestArrival: destLatest ? new Date(destLatest).toISOString() : null,
                      },
                    ]
                  : []),
              ]
              const brief = {
                grossWeightKg: Number.isFinite(kg) && kg > 0 ? kg : null,
                adrClass: adrClass.trim() || null,
                autoFindRoute: true,
                autoRehearse: false,
                ...(timeWindows.length > 0 ? { timeWindows } : {}),
              }
              const trip = client.buildTripFromStops(
                orgId,
                vehicleId,
                { ...originStop, id: originId },
                { ...destStop, id: destId },
                brief,
              )
              const pushed = await client.pushTrip(trip)
              setLastTrip(pushed)
              setLiveTrip(pushed)
            })
          }
        >
          Push trip
        </button>
        {pushBlockedByHealth ? (
          <p className="muted">
            Connect to the fleet server — health pill must show Connected (not Auth failed /
            Offline) before push.
          </p>
        ) : null}
      </section>

      <section className="panel">
        <h2>Fleet roster</h2>
        {rosterVehicles.length === 0 ? (
          <p className="muted">Register vehicles to see live status across the fleet.</p>
        ) : (
          <>
            <p className="muted">
              Polling {rosterRows.length || rosterVehicles.length} vehicle
              {(rosterRows.length || rosterVehicles.length) === 1 ? '' : 's'}
              {filteredVehicles.length > ROSTER_VEHICLE_CAP
                ? ` (capped at ${ROSTER_VEHICLE_CAP})`
                : ''}
              . Click a row to select.
            </p>
            {rosterError ? <p className="muted roster-warn">{rosterError}</p> : null}
            <div className="roster-wrap">
              <table className="roster">
                <thead>
                  <tr>
                    <th>Vehicle</th>
                    <th>Status</th>
                    <th>ETA</th>
                    <th>GPS</th>
                    <th>Defects</th>
                  </tr>
                </thead>
                <tbody>
                  {(rosterRows.length > 0
                    ? rosterRows
                    : buildRosterRows(rosterVehicles, {}, Date.now())
                  ).map((row) => (
                    <tr
                      key={row.vehicleId}
                      className={
                        row.vehicleId === vehicleId ? 'roster__row roster__row--active' : 'roster__row'
                      }
                      onClick={() => setVehicleId(row.vehicleId)}
                    >
                      <td>
                        {row.label}
                        {row.plate ? (
                          <span className="muted"> · {row.plate}</span>
                        ) : null}
                      </td>
                      <td>{row.trip?.status ?? 'idle'}</td>
                      <td>{formatPhysicsEta(row.trip?.physicsETASeconds)}</td>
                      <td>{formatGpsAge(row.gpsAgeSeconds)}</td>
                      <td>{row.hasDefects ? 'Yes' : '—'}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </>
        )}
      </section>

      <section className="panel">
        <h2>Driver snapshot</h2>
        {inspectionToast ? (
          <p className="inspection-toast" role="status">
            {inspectionToast}
            <button
              type="button"
              className="button-secondary"
              onClick={() => setInspectionToast(null)}
            >
              Dismiss
            </button>
          </p>
        ) : null}
        {snapshotTrip ? (
          <div className="status">
            <p>
              Trip <code>{snapshotTrip.id}</code> · status <strong>{snapshotTrip.status}</strong>
              {snapshotTrip.physicsETASeconds != null
                ? ` · physics ETA ${Math.round(snapshotTrip.physicsETASeconds / 60)} min`
                : ' · waiting for driver ETA'}
            </p>
            {snapshotTrip.driverLatitude != null && snapshotTrip.driverLongitude != null ? (
              <p className="muted">
                Last GPS:{' '}
                {snapshotTrip.driverLatitude.toFixed(5)}, {snapshotTrip.driverLongitude.toFixed(5)}
                {snapshotTrip.driverLocationRecordedAt
                  ? ` · ${new Date(snapshotTrip.driverLocationRecordedAt).toLocaleTimeString()}`
                  : ''}
              </p>
            ) : (
              <p className="muted">Last GPS: waiting for driver position</p>
            )}
            {inspectionHasDefects(snapshotTrip) && snapshotTrip.latestInspectionSummary ? (
              <div className="inspection-card">
                <div className="inspection-card__header">
                  <strong>Walkaround defects</strong>
                  {snapshotTrip.inspectionReportPDFBase64 ? (
                    <button
                      type="button"
                      className="button-secondary"
                      onClick={() =>
                        downloadInspectionPdf(
                          snapshotTrip.inspectionReportPDFBase64!,
                          `walkaround-${snapshotTrip.id.slice(0, 8)}.pdf`,
                        )
                      }
                    >
                      Download PDF
                    </button>
                  ) : null}
                </div>
                <p className="inspection-card__line">
                  {inspectionSummaryLine(snapshotTrip.latestInspectionSummary)}
                </p>
                <p className="muted">
                  Driver-reported defects — verify in the operator defect system before dispatch.
                </p>
              </div>
            ) : null}
            <ul>
              {snapshotTrip.stops.map((s) => (
                <li key={s.id}>
                  {s.role}: {s.label} ({s.latitude.toFixed(4)}, {s.longitude.toFixed(4)})
                </li>
              ))}
            </ul>
          </div>
        ) : (
          <p className="muted">No active trip yet. Push a trip, then wait for the driver phone.</p>
        )}
        <TripMapPreview
          trip={snapshotTrip}
          client={healthOk ? client : null}
          vehicleProfile={
            snapshotTrip?.jobBrief?.grossWeightKg != null
              ? { weightTonnes: snapshotTrip.jobBrief.grossWeightKg / 1000 }
              : null
          }
          onRoutePreviewError={(msg) => setError(msg)}
          fleetPins={rosterDriverPins(rosterRows)}
          selectedVehicleId={vehicleId || null}
        />
      </section>

      {error ? <p className="error">{error}</p> : null}

      <footer className="muted">
        Operator guide: Docs/web-dispatch-operator-guide.md · API contract: Docs/pilot-fleet-pack.md
      </footer>
    </div>
  )
}
