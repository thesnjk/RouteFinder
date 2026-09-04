import { useCallback, useEffect, useMemo, useState } from 'react'
import './App.css'
import { FleetApiClient } from './fleet/client'
import type { FleetOrg, FleetProxyStatus, FleetTrip, FleetVehicle } from './fleet/types'
import { TripMapPreview } from './TripMapPreview'
import { VehicleQR } from './VehicleQR'

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
  const [newOrgName, setNewOrgName] = useState('Pilot fleet')
  const [newVehicleLabel, setNewVehicleLabel] = useState('Unit 1')
  const [originLabel, setOriginLabel] = useState('Norwich')
  const [destLabel, setDestLabel] = useState("King's Lynn")
  const [lastTrip, setLastTrip] = useState<FleetTrip | null>(null)
  const [liveTrip, setLiveTrip] = useState<FleetTrip | null>(null)
  const [error, setError] = useState<string | null>(null)
  const [busy, setBusy] = useState(false)
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
    const h = await client.health()
    setHealthOk(h.ok)
    setHealth(h.ok ? `Connected · version ${h.version}` : 'not ok')
    try {
      setProxyStatus(await client.proxyStatus())
    } catch {
      setProxyStatus(null)
    }
  }, [client, persist])

  useEffect(() => {
    if (!vehicleId) {
      setLiveTrip(null)
      return
    }
    let cancelled = false
    const tick = async () => {
      try {
        const trip = await client.activeTrip(vehicleId)
        if (!cancelled) setLiveTrip(trip)
      } catch {
        /* ignore poll errors */
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
  ]

  return (
    <div className="app">
      <header>
        <h1>RouteFinder Web Dispatch</h1>
        <p className="muted">
          LAN console for <code>RouteFinderFleetServer</code> — not a hosted SaaS portal.
        </p>
        <div className={`health-pill ${healthOk ? 'health-pill--ok' : ''}`}>{health}</div>
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
            placeholder="/fleet or http://192.168.1.10:8080"
          />
        </label>
        <label>
          API key (optional)
          <input
            value={apiKey}
            onChange={(e) => setApiKey(e.target.value)}
            placeholder="Bearer token if server uses --api-key"
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
          <p className="muted">
            ORS proxy:{' '}
            {proxyStatus.orsConfigured
              ? `on · ${proxyStatus.routesToday}/${proxyStatus.routeDailyCap} routes today`
              : 'off (start server with --ors-key so drivers need no HeiGIT keys)'}
          </p>
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
          Vehicle
          <select value={vehicleId} onChange={(e) => setVehicleId(e.target.value)}>
            <option value="">Select…</option>
            {vehicles.map((v) => (
              <option key={v.id} value={v.id}>
                {v.label} ({v.id.slice(0, 8)})
              </option>
            ))}
          </select>
        </label>
        {vehicleId && selectedVehicle ? (
          <VehicleQR vehicleId={vehicleId} label={selectedVehicle.label} />
        ) : null}
      </section>

      <section className="panel">
        <h2>Push trip</h2>
        <label>
          Origin label
          <input value={originLabel} onChange={(e) => setOriginLabel(e.target.value)} />
        </label>
        <label>
          Destination label
          <input value={destLabel} onChange={(e) => setDestLabel(e.target.value)} />
        </label>
        <p className="muted">
          Demo coordinates: Norwich → King&apos;s Lynn. Dev tip: use base URL <code>/fleet</code> if
          direct :8080 fails with CORS.
        </p>
        <button
          disabled={busy || !orgId || !vehicleId}
          onClick={() =>
            run(async () => {
              persist()
              const trip = client.buildDemoTrip(orgId, vehicleId, originLabel, destLabel)
              const pushed = await client.pushTrip(trip)
              setLastTrip(pushed)
              setLiveTrip(pushed)
            })
          }
        >
          Push trip
        </button>
      </section>

      <section className="panel">
        <h2>Driver snapshot</h2>
        {snapshotTrip ? (
          <div className="status">
            <p>
              Trip <code>{snapshotTrip.id}</code> · status <strong>{snapshotTrip.status}</strong>
              {snapshotTrip.physicsETASeconds != null
                ? ` · physics ETA ${Math.round(snapshotTrip.physicsETASeconds / 60)} min`
                : ' · waiting for driver ETA'}
            </p>
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
        <TripMapPreview trip={snapshotTrip} />
      </section>

      {error ? <p className="error">{error}</p> : null}

      <footer className="muted">
        Operator guide: Docs/web-dispatch-operator-guide.md · API contract: Docs/pilot-fleet-pack.md
      </footer>
    </div>
  )
}
