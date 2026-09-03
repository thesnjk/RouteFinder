import { useCallback, useMemo, useState } from 'react'
import './App.css'
import { FleetApiClient } from './fleet/client'
import type { FleetOrg, FleetTrip, FleetVehicle } from './fleet/types'

const STORAGE_KEY = 'routefinder.webDispatch.connection'

function loadConnection(): { baseUrl: string; apiKey: string } {
  try {
    const raw = localStorage.getItem(STORAGE_KEY)
    if (raw) return JSON.parse(raw) as { baseUrl: string; apiKey: string }
  } catch {
    /* ignore */
  }
  return { baseUrl: 'http://127.0.0.1:8080', apiKey: '' }
}

export default function App() {
  const [baseUrl, setBaseUrl] = useState(() => loadConnection().baseUrl)
  const [apiKey, setApiKey] = useState(() => loadConnection().apiKey)
  const [health, setHealth] = useState<string>('Not checked')
  const [orgs, setOrgs] = useState<FleetOrg[]>([])
  const [vehicles, setVehicles] = useState<FleetVehicle[]>([])
  const [orgId, setOrgId] = useState('')
  const [vehicleId, setVehicleId] = useState('')
  const [newOrgName, setNewOrgName] = useState('Pilot fleet')
  const [newVehicleLabel, setNewVehicleLabel] = useState('Unit 1')
  const [originLabel, setOriginLabel] = useState('Manchester')
  const [destLabel, setDestLabel] = useState('Liverpool')
  const [lastTrip, setLastTrip] = useState<FleetTrip | null>(null)
  const [error, setError] = useState<string | null>(null)
  const [busy, setBusy] = useState(false)

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

  return (
    <div className="app">
      <header>
        <h1>RouteFinder Web Dispatch</h1>
        <p className="muted">
          LAN console for <code>RouteFinderFleetServer</code> — not a hosted SaaS portal.
        </p>
      </header>

      <section className="panel">
        <h2>Connection</h2>
        <label>
          Server base URL
          <input
            value={baseUrl}
            onChange={(e) => setBaseUrl(e.target.value)}
            placeholder="http://192.168.1.10:8080"
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
          <button
            disabled={busy}
            onClick={() =>
              run(async () => {
                persist()
                const h = await client.health()
                setHealth(h.ok ? `ok · version ${h.version}` : 'not ok')
              })
            }
          >
            Test /health
          </button>
          <span className="muted">{health}</span>
        </div>
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
        {vehicleId ? (
          <p className="mono">
            Driver vehicle UUID (paste into iOS Settings → Fleet): <code>{vehicleId}</code>
          </p>
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
          Demo coordinates: Manchester → Liverpool. Geocoding / MapLibre preview comes in a follow-up.
        </p>
        <button
          disabled={busy || !orgId || !vehicleId}
          onClick={() =>
            run(async () => {
              persist()
              const trip = client.buildDemoTrip(orgId, vehicleId, originLabel, destLabel)
              const pushed = await client.pushTrip(trip)
              setLastTrip(pushed)
            })
          }
        >
          Push trip
        </button>
        {lastTrip ? (
          <div className="status">
            <p>
              Pushed <code>{lastTrip.id}</code> · status <strong>{lastTrip.status}</strong>
            </p>
            <ul>
              {lastTrip.stops.map((s) => (
                <li key={s.id}>
                  {s.role}: {s.label} ({s.latitude.toFixed(4)}, {s.longitude.toFixed(4)})
                </li>
              ))}
            </ul>
          </div>
        ) : null}
      </section>

      {error ? <p className="error">{error}</p> : null}

      <footer className="muted">
        See Docs/pilot-fleet-pack.md for the API contract. Hosted multi-tenant SaaS is out of scope for
        v1.
      </footer>
    </div>
  )
}
