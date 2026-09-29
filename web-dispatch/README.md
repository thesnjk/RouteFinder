# RouteFinder Web Dispatch

Browser console for office PCs (Windows / Linux / Mac) that talks to **`RouteFinderFleetServer`** (LAN) or the **hosted gateway** over HTTP(S). This is **not** a multi-tenant SaaS admin portal.

## Prerequisites

```bash
# Terminal A — LAN fleet server (operator-paid ORS when keyed)
# From the repo root, enter the Swift package directory:
cd RouteFinder
swift run RouteFinderFleetServer --port 8080 --ors-key "$ORS_API_KEY"
```

Or point Connection at a deployed hosted gateway (`https://fleet.yourdomain.com`) — see [`../Docs/hosted-gateway-deployment.md`](../Docs/hosted-gateway-deployment.md).

## Run

```bash
cd web-dispatch
npm install
npm run dev
```

Open http://127.0.0.1:5173

- Connection base URL defaults to **`/fleet`** (Vite CORS proxy → `:8080`)
- Or use `http://<mac-ip>:8080` directly (fleet CORS enabled)
- Or use `https://fleet.yourdomain.com` + org bearer token for remote depots
- First-run tour → **Bootstrap demo fleet** (or Create org → register vehicle) → show **QR** → Push trip
- Driver snapshot panel + MapLibre corridor preview
- Walkaround defects card + optional PDF download when the phone publishes an inspection summary

Operator steps: [`../Docs/web-dispatch-operator-guide.md`](../Docs/web-dispatch-operator-guide.md)

## Scripts

| Command | Purpose |
|---------|---------|
| `npm run dev` | Local UI |
| `npm run build` | Production bundle |
| `npm test` | URL / auth header smoke |
| `npm run lint` | oxlint |

## Scope

- Org / vehicle / push trip against REST API
- Onboarding tour + connection health pill
- Vehicle pairing QR (`routefinder-vehicle:<uuid>`)
- Active-trip snapshot poll + MapLibre preview (job brief weight / ADR / time windows on push)
- Walkaround defect card + PDF in Driver snapshot when `latestInspectionSummary.defectCount > 0`
- Geocode stop search via fleet Pelias proxy
- ORS + optional TomTom / OpenWeather proxy status from `/v1/proxy/status`
- Hosted HTTPS base URL supported (same client as LAN)
- **Not yet:** billing UI / self-serve multi-tenant admin
