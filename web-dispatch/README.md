# RouteFinder Web Dispatch (LAN)

Browser console for office PCs (Windows / Linux / Mac) that talks to the existing **`RouteFinderFleetServer`** over HTTP. This is **not** a hosted multi-tenant SaaS portal.

Scaffolded with Vite + React + TypeScript (SPA fits LAN better than SSR).

## Prerequisites

```bash
# Terminal A — fleet server
cd /Users/admin/Developer/RouteFinder/RouteFinder
swift run RouteFinderFleetServer --port 8080
```

## Run

```bash
cd /Users/admin/Developer/RouteFinder/web-dispatch
npm install
npm run dev
```

Open http://127.0.0.1:5173

- Connection base URL defaults to **`/fleet`** (Vite CORS proxy → `:8080`)
- Or use `http://127.0.0.1:8080` directly once fleet CORS middleware is enabled
- Create org → register vehicle → copy vehicle UUID into the iOS app Fleet settings → Push trip

## Scripts

| Command | Purpose |
|---------|---------|
| `npm run dev` | Local UI |
| `npm run build` | Production bundle |
| `npm test` | URL / auth header smoke |
| `npm run lint` | oxlint |

## v1 scope

- Org / vehicle / push trip against REST API
- Manual server URL + optional API key
- **Not yet:** MapLibre preview, ORS geocode, snapshot status panel, hosted relay

API contract: [`Docs/pilot-fleet-pack.md`](../Docs/pilot-fleet-pack.md)
