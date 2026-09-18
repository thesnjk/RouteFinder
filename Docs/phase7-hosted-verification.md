# Phase 7 — Hosted gateway verification

Exit gate checklist for remote depots without office LAN.

## Preconditions

- [ ] `hosted-gateway` deployed with TLS ([hosted-gateway-deployment.md](hosted-gateway-deployment.md))
- [ ] `ORS_API_KEY` set on the server only
- [ ] At least one org in `config/orgs.json` with a strong `bearerToken`
- [ ] CI: `hosted-gateway` job green (`npm test` + typecheck)

## Server

- [ ] `GET /health` → `{ "ok": true, "version": "1" }` without auth
- [ ] `GET /v1/orgs` without token → 401
- [ ] `GET /v1/orgs` with org bearer → 200 and seeded org present
- [ ] `GET /v1/proxy/status` shows `orsConfigured: true` when key is set

## Web dispatch (hosted URL)

- [ ] Connection base URL = `https://…` + org bearer token
- [ ] Test /health succeeds
- [ ] Geocode stop via Pelias proxy (not hardcoded coords)
- [ ] Create/select vehicle, push trip

## Driver on cellular (iOS or Android)

- [ ] Fleet wizard → **Hosted (HTTPS)** (not LAN discovery)
- [ ] Paste HTTPS URL + org token; Test /health succeeds
- [ ] Pair vehicle UUID from dispatch QR
- [ ] SSE receives `tripPushed` while **not** on office Wi‑Fi
- [ ] Find HGV route via `/v1/proxy/ors/…` **without** a HeiGIT key on the device

## Metering persistence

- [ ] After a geocode/route, `/v1/proxy/status` increments
- [ ] Restart `hosted-gateway` process
- [ ] Counts for the same calendar day are unchanged

## Operator key rotation

- [ ] Change `ORS_API_KEY` on VPS, restart
- [ ] Devices keep working with the same org bearer token
- [ ] Devices still have no operator ORS key

## LAN parity (optional)

- [ ] macOS `RouteFinderFleetServer` writes `proxy-meter.json` under fleet storage and restores counts after restart (`fleetProxyUsageMeterPersistsAcrossRestart`)

## Honest limits

- No billing UI / self-serve org admin
- No TomTom proxy in this phase
- Cloudflare Worker is **not** the primary deploy path
