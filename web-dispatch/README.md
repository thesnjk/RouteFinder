# RouteFinder Web Dispatch (LAN)

Browser console for office PCs (Windows / Linux / Mac) that talks to the existing **`RouteFinderFleetServer`** over HTTP. This is **not** a hosted multi-tenant SaaS portal.

## Prerequisites

```bash
# Terminal A — fleet server (operator-paid ORS when keyed)
cd /Users/admin/Developer/RouteFinder/RouteFinder
swift run RouteFinderFleetServer --port 8080 --ors-key "$ORS_API_KEY"
```

## Run

```bash
cd /Users/admin/Developer/RouteFinder/web-dispatch
npm install
npm run dev
```

Open http://127.0.0.1:5173

- Connection base URL defaults to **`/fleet`** (Vite CORS proxy → `:8080`)
- Or use `http://<mac-ip>:8080` directly (fleet CORS enabled)
- First-run tour → Create org → register vehicle → show **QR** → Push trip
- Driver snapshot panel + MapLibre corridor preview

Operator steps: [`../Docs/web-dispatch-operator-guide.md`](../Docs/web-dispatch-operator-guide.md)

## Scripts

| Command | Purpose |
|---------|---------|
| `npm run dev` | Local UI |
| `npm run build` | Production bundle |
| `npm test` | URL / auth header smoke |
| `npm run lint` | oxlint |

## v1.5 scope

- Org / vehicle / push trip against REST API
- Onboarding tour + connection health pill
- Vehicle pairing QR (`routefinder-vehicle:<uuid>`)
- Active-trip snapshot poll + MapLibre preview
- ORS proxy status from `/v1/proxy/status`
- **Not yet:** hosted relay, geocode stop search, live GPS fleet map
