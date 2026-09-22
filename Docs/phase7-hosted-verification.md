# Phase 7 — Hosted gateway verification

Exit gate checklist for remote depots without office LAN.

Last updated: 2026-09-18 (Engineering excellence Phase 4)

## Preconditions

- [ ] `hosted-gateway` deployed with TLS ([hosted-gateway-deployment.md](hosted-gateway-deployment.md)) — **Pending local (operator)** for production VPS
- [ ] `ORS_API_KEY` set on the server only — **Pass** (local smoke 2026-09-18 used env key)
- [x] At least one org configured (dev default `dev-org-token` or `config/orgs.json`)
- [x] CI: `hosted-gateway` job green (`npm test` + typecheck) — **Pass** 2026-09-18 (8 tests)

## Server

| Check | Result | Evidence |
|-------|--------|----------|
| `GET /health` → `{ "ok": true, "version": "1" }` without auth | **Pass** | Local curl `:18787` + `gateway.test.ts` |
| `GET /v1/orgs` without token → 401 | **Pass** | Local curl + vitest |
| `GET /v1/orgs` with org bearer → 200 and seeded org present | **Pass** | Bearer `dev-org-token` / vitest `test-token-alpha` |
| `GET /v1/proxy/status` shows `orsConfigured: true` when key is set | **Pass** | Local smoke with `ORS_API_KEY` |

### Local curl smoke (no VPS)

```bash
cd hosted-gateway
DATA_DIR=$(mktemp -d) PORT=18787 ORS_API_KEY=fake-ors-for-smoke npm start
# other terminal:
curl -sS http://127.0.0.1:18787/health
curl -sS -o /dev/null -w "%{http_code}\n" http://127.0.0.1:18787/v1/orgs   # expect 401
curl -sS -H "Authorization: Bearer dev-org-token" http://127.0.0.1:18787/v1/orgs
curl -sS -H "Authorization: Bearer dev-org-token" http://127.0.0.1:18787/v1/proxy/status
```

## Web dispatch (hosted URL)

- [ ] Connection base URL = `https://…` + org bearer token — **Pending local (operator)**
- [ ] Test /health succeeds — **Pending local (operator)**
- [ ] Geocode stop via Pelias proxy (not hardcoded coords) — **Pending local (operator)**
- [ ] Create/select vehicle, push trip — **Pending local (operator)**

## Driver on cellular (iOS or Android)

- [ ] Fleet wizard → **Hosted (HTTPS)** (not LAN discovery) — **Pending local (operator)**
- [ ] Paste HTTPS URL + org token; Test /health succeeds — **Pending local (operator)**
- [ ] Pair vehicle UUID from dispatch QR — **Pending local (operator)**
- [ ] SSE receives `tripPushed` while **not** on office Wi‑Fi — **Pending local (operator)**
- [ ] Find HGV route via `/v1/proxy/ors/…` **without** a HeiGIT key on the device — **Pending local (operator)**

**Client pointer (code):** iOS `FleetWorkspaceSettings.saveFleetServerURL` / `saveRemoteFleetConfiguration` sets `FleetConnectionKind.hosted` when scheme is `https`. Unit test: `httpsFleetURLInfersHostedConnectionKind`. Wizard: `FleetSetupWizardView` Hosted (HTTPS) mode.

## Metering persistence

- [x] After a geocode/route, `/v1/proxy/status` increments — covered by `gateway.test.ts` metering cases
- [x] Restart `hosted-gateway` process — vitest persistence suite
- [x] Counts for the same calendar day are unchanged — vitest persistence suite

## Operator key rotation

- [ ] Change `ORS_API_KEY` on VPS, restart — **Pending local (operator)**
- [ ] Devices keep working with the same org bearer token — **Pending local (operator)**
- [ ] Devices still have no operator ORS key — **Pending local (operator)**

## LAN parity (optional)

- [x] macOS `RouteFinderFleetServer` writes `proxy-meter.json` under fleet storage and restores counts after restart (`fleetProxyUsageMeterPersistsAcrossRestart`) — covered in package tests / fleet smoke surface

## Honest limits

- No billing UI / self-serve org admin
- No TomTom proxy in this phase
- Cloudflare Worker is **not** the primary deploy path
