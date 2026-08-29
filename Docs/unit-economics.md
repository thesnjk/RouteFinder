# Unit economics and API metering

RouteFinder tracks outbound API calls on-device to protect free-tier quotas during driver sessions. Metering is **measure-first**: every paid or limited provider records a ledger entry before additional caches or throttles are added.

## Providers

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

Budgets are **soft limits** — they do not block routing or geocoding. When a non-critical provider exceeds its soft budget, background polls are skipped and Settings shows an orange banner.

## Guard behavior

1. **TomTom hazard sampling** — skipped when `tomTomFlow` is at/above the soft limit (`APIUsageLedger.allowsNonCriticalRequest`).
2. **Overpass roadworks corridor refresh** — skipped at the repository boundary before HTTP.
3. **Settings panel** — read-only “API Usage Today” under API Keys shows `count / softLimit` per provider.

## Persistence

`APIUsageLedger` (actor, `DataLayer/Metering`) rolls up `(provider, timestamp)` into calendar-day counts persisted under Application Support (`RouteFinder/metering/api-usage.json`).

## Cost model vs physics cost model

The `CostModel` module remains route physics and simulation economics. Unit economics metering lives in `Contracts/Metering` + `DataLayer/Metering` and is unrelated to edge traversal weights.

## Operational guidance

- Tune soft budgets in `APIUsageBudget.defaultBudget(for:)` when provider tiers change.
- Review Settings usage after long dispatch rehearsals or fleet E2E runs.
- Prefer fixing retry storms (`RemoteRequestPolicy`) before lowering soft budgets.
