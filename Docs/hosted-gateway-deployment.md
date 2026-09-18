# Hosted gateway deployment (VPS)

All-in-one HTTPS fleet API for **remote depots** that cannot use office LAN. Implements the same REST/SSE and ORS/Pelias proxy surface as `RouteFinderFleetServer`, with **per-org bearer tokens** and **disk-persisted** metering.

Package: [`hosted-gateway/`](../hosted-gateway/).

## What you get

| Capability | Detail |
|------------|--------|
| Fleet API | `health`, `v1/orgs`, vehicles, trips, snapshots, SSE events |
| ORS proxy | `/v1/proxy/ors/…` and `/v1/proxy/pelias/…` with operator `ORS_API_KEY` |
| Auth | Org bearer token via `Authorization: Bearer` or `X-Fleet-API-Key` |
| Metering | Per-org `data/<orgId>/proxy-meter.json` (survives restarts) |
| Multi-tenant | Config file / env only — **no billing UI** |

Clients (iOS, Android, web-dispatch) already speak this HTTP surface — point them at `https://fleet.yourdomain.com` and the org token.

## Sizing

A small VPS is enough for ≤20 trucks:

- 1 vCPU, 1–2 GB RAM, 20 GB disk
- Ubuntu 22.04+ or similar
- Node.js **20+**

## Install

```bash
git clone <your-repo> RouteFinder
cd RouteFinder/hosted-gateway
cp config/orgs.example.json config/orgs.json
# Edit bearerToken to long random secrets; keep org ids stable once devices are paired
npm ci
```

Generate tokens (example):

```bash
openssl rand -hex 32
```

Environment (systemd or shell):

```bash
export ORS_API_KEY="your-heigit-key"          # operator key — never give to drivers
export DATA_DIR="/var/lib/routefinder-fleet"
export PORT=8787
export TRUST_PROXY=1                          # when behind Caddy/nginx
# optional instead of config/orgs.json:
# export ROUTEFINDER_ORGS_JSON='[{"id":"...","name":"...","bearerToken":"..."}]'
```

Run:

```bash
npm start
```

## TLS with Caddy (recommended)

Caddyfile:

```
fleet.yourdomain.com {
  reverse_proxy 127.0.0.1:8787
}
```

Point DNS A/AAAA at the VPS. Clients use `https://fleet.yourdomain.com` (no path prefix).

nginx equivalent: `proxy_pass http://127.0.0.1:8787;` with Let’s Encrypt certs.

## Smoke test

```bash
curl -s https://fleet.yourdomain.com/health
# {"ok":true,"version":"1"}

curl -s -H "Authorization: Bearer YOUR_ORG_TOKEN" \
  https://fleet.yourdomain.com/v1/proxy/status
```

1. Open **web-dispatch** → Connection → paste `https://fleet.yourdomain.com` + org token → Test /health.
2. Geocode a stop (needs ORS proxy on).
3. Push a trip to a vehicle UUID.
4. On a phone **on cellular**, run fleet setup → **Hosted (HTTPS)** → same URL + token → pair vehicle → receive SSE trip → Find route (no device ORS key).
5. Restart the Node process; `GET /v1/proxy/status` still shows today’s counts.

## Rotating the operator ORS key

Change `ORS_API_KEY` on the VPS and restart. Org bearer tokens and devices stay unchanged. Fleets never see the HeiGIT key.

## Cloudflare Worker note

Phase 7 primary path is this **VPS all-in-one**. A Cloudflare Worker edge layer (auth + ORS-only) in front of the same VPS is optional later — not required for remote depots. If you add edge auth later, keep fleet REST/SSE on the VPS (SSE + long connections fit poorly on short Worker isolates).

## LAN vs hosted

| Mode | When |
|------|------|
| Office LAN `RouteFinderFleetServer` | Same Wi‑Fi pilots; Bonjour discovery |
| Hosted gateway | Home office, remote depot, cellular drivers |

See [fleet-setup-guide.md](fleet-setup-guide.md) and [phase7-hosted-verification.md](phase7-hosted-verification.md).
