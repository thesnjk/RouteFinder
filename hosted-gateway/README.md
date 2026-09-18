# RouteFinder hosted gateway

All-in-one HTTPS-ready fleet API for remote depots (no office LAN required).

Exposes the same REST/SSE and ORS/Pelias proxy surface as `RouteFinderFleetServer`, with **per-org bearer tokens** and **disk-persisted** proxy metering.

## Quick start

```bash
cd hosted-gateway
cp config/orgs.example.json config/orgs.json
# edit bearerToken values
export ORS_API_KEY="your-heigit-key"
npm ci
npm start
```

Default listen port: **8787** (`PORT` env). Data directory: `./data` (`DATA_DIR`).

## Auth

Clients send either:

- `Authorization: Bearer <org-token>`
- `X-Fleet-API-Key: <org-token>`

`GET /health` is unauthenticated. All `/v1/*` routes require a configured org token.

## Config

| Source | Purpose |
|--------|---------|
| `config/orgs.json` or `ROUTEFINDER_ORGS_JSON` | Org id, name, bearer token, optional daily caps |
| `ORS_API_KEY` | Operator HeiGIT key (never shared with devices) |
| `DATA_DIR` | Per-org JSON store + meter files |
| `PORT` | Listen port |

See [Docs/hosted-gateway-deployment.md](../Docs/hosted-gateway-deployment.md).

## Tests

```bash
npm test
npm run typecheck
```
