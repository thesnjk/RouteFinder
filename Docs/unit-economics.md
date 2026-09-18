# Unit economics and API metering

RouteFinder tracks outbound API calls to protect free-tier quotas and to support **operator-paid** fleet routing (customers do not paste HeiGIT keys when the fleet ORS proxy is enabled).

Last updated: 2026-09-17

## Providers (on-device ledger)

| Provider | Ledger key | Default soft daily budget | Critical? |
|----------|------------|---------------------------|-----------|
| HeiGIT ORS routing | `orsRoute` | 2,000 | Yes |
| HeiGIT ORS geocoding | `orsGeocode` | 2,000 | Yes |
| HeiGIT ORS matrix | `orsMatrix` | 2,000 | Yes |
| TomTom Traffic Flow | `tomTomFlow` | 2,500 | No (poll) |
| Overpass roadworks | `overpass` | 10,000 | No (poll) |
| OpenWeather | `openWeather` | 1,000 | Yes |
| RegCheck | `regCheck` | 50 | Yes |
| DVLA VES | `dvla` | 100 | Yes |

Budgets are **soft limits** on-device — they do not block routing or geocoding. When a non-critical provider exceeds its soft budget, background polls are skipped and Settings shows an orange banner.

## Fleet server ORS proxy (operator-paid)

When `RouteFinderFleetServer` is started with `--ors-key` / `ORS_API_KEY`:

| Endpoint | Upstream |
|----------|----------|
| `POST /v1/proxy/ors/v2/directions/driving-hgv/geojson` | HeiGIT ORS |
| `POST /v1/proxy/ors/v2/directions/driving-car/geojson` | HeiGIT ORS |
| `POST /v1/proxy/ors/v2/matrix/*` | HeiGIT matrix |
| `GET /v1/proxy/pelias/v1/search` | HeiGIT Pelias |
| `GET /v1/proxy/status` | Metering snapshot |

**Hard daily caps** (default 2,000 routes / 2,000 geocodes) return HTTP 429 when exceeded. Tune with `--route-daily-cap` / `--geocode-daily-cap`.

Driver apps with **Use remote fleet server** route through this proxy and do not need a local HeiGIT key.

## Guard behavior (on-device)

1. **TomTom hazard sampling** — skipped when `tomTomFlow` is at/above the soft limit (`APIUsageLedger.allowsNonCriticalRequest`).
2. **Overpass roadworks corridor refresh** — skipped at the repository boundary before HTTP.
3. **Settings panel** — read-only “API Usage Today” under API Keys shows `count / softLimit` per provider.

## Persistence

`APIUsageLedger` (actor, `DataLayer/Metering`) rolls up `(provider, timestamp)` into calendar-day counts persisted under Application Support (`RouteFinder/metering/api-usage.json`).

Fleet proxy metering (`FleetProxyUsageMeter`) persists calendar-day counts under the fleet storage directory (`proxy-meter.json`). Hosted gateway meters per org under `data/<orgId>/proxy-meter.json`.

## Cost model vs physics cost model

The `CostModel` module remains route physics and simulation economics. Unit economics metering lives in `Contracts/Metering` + `DataLayer/Metering` + `FleetServerCore` and is unrelated to edge traversal weights.

## Pricing fair-use (subscription narrative)

**API-included desk subscription** (align with [`pilot-fleet-pack.md`](pilot-fleet-pack.md)):

| Tier | Scope | Indicative price | Included |
|------|--------|------------------|----------|
| Pilot | ≤3 phones, 60 days | **£0** | Setup + feedback |
| Desk LAN | ≤10 trucks, office LAN server | **£39/mo** (band £29–£49) | Fleet console + **ORS/Pelias proxy** fair-use (2k route / 2k geocode per day per server) |
| Desk + remote | Hosted gateway VPS | **£49–£79/mo** + VPS pass-through | Same API caps **per org** on gateway; Operator owns VPS |
| Extra trucks | >10 on same desk | **£3–£5/truck/mo** (negotiable) | Same proxy caps — abuse = 429 |
| Owner-operator App Store | Single driver | **Deferred** post-pilot | Separate SKU later |

**API cost included** means Provider/Operator supplies HeiGIT usage via fleet `--ors-key` / hosted `ORS_API_KEY` — **not** unlimited planet-scale routing. Fair-use = hard caps above; abuse / quota exhaustion is Operator’s responsibility to escalate with Provider. Hosted gateway metering is config/token based ([hosted-gateway-deployment.md](hosted-gateway-deployment.md)); billing UI remains deferred.

## Operational guidance

- Tune soft budgets in `APIUsageBudget.defaultBudget(for:)` when provider tiers change.
- Prefer fixing retry storms (`RemoteRequestPolicy`) before lowering soft budgets.
- Always pass `--ors-key` for pilot fleets so hauliers never create HeiGIT accounts.
