# RouteFinder — project writeup

Living end-to-end narrative of what RouteFinder is, which surfaces ship today, and what remains gated. Integers and verification stay in the scorecard / phase Docs — this file tells the story and points at those SSOTs.

Last updated: 2026-11-11  
Status: **iterative** (Ch 1–4 drafted; Ch 5–8 stubbed — next attach fills Ch 5)  
Gated product work (AA / CarPlay / VU / live £ / HD / Stripe / Android offline / country PBF) resumes only when unlocked by name.

---

## Table of contents

1. [What RouteFinder is](#1-what-routefinder-is)
2. [Surfaces map](#2-surfaces-map)
3. [Fleet and hosted desk today](#3-fleet-and-hosted-desk-today)
4. [Routing, UK living layer, compliance](#4-routing-uk-living-layer-compliance)
5. [Competitive posture](#5-competitive-posture) *(stub)*
6. [Architecture and repo layout](#6-architecture-and-repo-layout) *(stub)*
7. [Operator / pilot path](#7-operator--pilot-path) *(stub)*
8. [Open gates and non-goals](#8-open-gates-and-non-goals) *(stub)*
9. [Changelog of writeup iterations](#9-changelog-of-writeup-iterations)

---

## 1. What RouteFinder is

RouteFinder is a native **HGV / truck navigator and fleet desk** aimed at UK operators. It plans constraint-aware routes (length / width / height / weight / axle / hazmat / ADR), rehearses them with vehicle physics, and keeps hours-of-service as an **advisory** overlay — the vehicle unit (VU) / digital tachograph remains the legal record.

The product is not a multi-tenant SaaS portal. The core experience is:

- **In-cab** — iOS gold-standard driver app plus Android C2 fleet driver (depot-issued handset; CarPlay / Android Auto not required for pilots).
- **Office desk** — Mac/iPad dispatch console and a browser desk (`web-dispatch`) for Windows/Linux PCs, talking to a LAN fleet server or an optional hosted gateway.
- **UK living layer** — RegCheck/DVLA plate profiles, truck POIs, LEZ/CAZ advisories and avoid rings (authored, not legal cadastre), named UK toll £ hints, crowd hazards fused with TomTom, layby occupancy priors.

**Owner:** Jacob Hackett. The repository and software are proprietary and confidential — see root [`LICENSE`](../LICENSE). No public redistribution rights except under written agreement.

**Legal (HOS):** RouteFinder’s HOS clock, imported card remainings, and “Can I drive now?” answers are planning aids only. Do not use them as a substitute for the legal tachograph record or enforcement decisions.

Deeper stranger-path UX: [`getting-started.md`](getting-started.md). Feature bullets and API-key notes: root [`README.md`](../README.md).

---

## 2. Surfaces map

| Surface | Role today | Primary path |
|---------|------------|--------------|
| **iOS driver** | Pair or solo ORS; rehearse / start; predictive fuse; layby / toll / LEZ / HOS advisory; crowd hazards | `RouteFinderApp.xcodeproj` + `RouteFinder/` UI / navigation coordinators |
| **Android C2** | Fleet ORS proxy client; MapLibre; SSE handoff; fuse parity slices; Connection wizard + home depot/meters | `android-fleet-driver/` — see [`android-c2-gate.md`](android-c2-gate.md) |
| **Mac / iPad desk** | Disk-backed org → trip → physics ETA; fleet roster / yard GPS pins; Connection Test proxy-status | Mac dispatch + Settings / FleetSetupWizard in the app package |
| **web-dispatch** | Vite + React LAN/hosted desk; roster; trip push; indicative tolls; predicted layby; Connection depot profiles | [`web-dispatch/`](../web-dispatch/README.md) |
| **Fleet server** | LAN sync, Bearer/`--api-key`, fair-use caps, push trip → driver | `RouteFinderFleetServer` (package / server target) |
| **Hosted gateway** | Operator VPS / Workers when depot Wi‑Fi fails; same `/v1/*` contract | `hosted-gateway/` + [`hosted-gateway-deployment.md`](hosted-gateway-deployment.md) |
| **Physics / sim** | Pre-trip kinetic risk, shareable trip brief (text/PDF), rehearsal vs play | Physics / rehearsal engines in `RouteFinder/` |
| **Compliance** | DVSA-style walkaround, HOS advisory (561 / WTD), LEZ avoid toggles | Walkaround + HOS modules; desk Can-I-drive cards |

CarPlay code paths exist but production entitlements are inactive. Android Auto and deep Android offline packs remain product-gated. Screenshots: [`screenshots/README.md`](screenshots/README.md).

---

## 3. Fleet and hosted desk today

Operators run either:

1. **Office LAN** — `RouteFinderFleetServer` on the depot network; drivers pair via discovery / QR; desk uses Connection base URL (web defaults to `/fleet` Vite proxy → `:8080`).
2. **Hosted (HTTPS)** — Operator gateway with org bearer tokens; drivers and desks point Connection at `https://fleet.yourdomain.com` (see deploy Doc).

**Account-Manager-lite (shipped MVP slice, 2026-11-11):** `GET /v1/proxy/status` returns depot identity (`orgId` / `orgName`) plus ORS (and related) meter fields. Contract: [`fleet-api-schema.json`](fleet-api-schema.json) (`FleetProxyDeskStatus`). UI parity:

- Web Connection / status panels (masked API key via `maskApiKey`)
- Mac Settings Connection Test + FleetSetupWizard Test + dispatch fleet-proxy panel
- Android FleetSetupWizard Test + DriverHome badge (`FleetProxyStatusLabels`)

Named depot profiles let the desk switch org tokens without re-pasting. **Stripe / self-serve billing is explicitly out of scope** for this MVP — residual under `EPIC-HOSTED-DESK`.

Deploy and Operator notes: [`hosted-gateway-deployment.md`](hosted-gateway-deployment.md). Fleet QA: [`fleet-e2e-qa.md`](fleet-e2e-qa.md).

---

## 4. Routing, UK living layer, compliance

How a trip is planned, annotated for UK HGV reality, and kept legally honest. Feature bullets mirror root [`README.md`](../README.md); status integers live in [`competitive-feature-scorecard.md`](competitive-feature-scorecard.md).

### Constraint routing

OpenRouteService drives HGV constraint routing: length / width / height / weight / axle / hazmat / ADR tunnel codes. Cab and desk can push trailer→ORS length ladders (12 / 16.5 / 18.75 / 25.25 m) while the constraint profile stays the documented baseline. Live TomTom flow sampling can trigger an ORS `avoid_polygons` recalculation when traffic warrants a reroute.

**Offline:** iOS uses H3 graph tiles with a hybrid ORS/offline policy, proactive corridor prefetch after Find (capped ≤ East Anglia), and Settings download regions (Norfolk demo, East Anglia mid-corridor, UK mainland large) plus optional on-device MapLibre packs — not Sygic-class country packs. Android offline packs remain product-gated.

### Physics rehearsal

Before commit, RouteFinder rehearses kinetic risk (grade, brake fade, slip) and can share a trip brief as plain text or PDF (with route map when geometry is available). Rehearse vs Play stays a stranger-path distinction in [`user-guide-simulation.md`](user-guide-simulation.md).

### UK living layer

- **Plate → profile** — RegCheck + DVLA for vehicle dimensions / class when configured.
- **Truck POIs** — fuel / parking / weigh / layby discovery along the job.
- **LEZ / CAZ** — banners and avoid-on-route using simplified authored rings for all 11 catalog zones (Settings toggle; **not** legal cadastral). Open-data densify MVP shipped for Sheffield + Birmingham + Bradford; other zones still coarse envelopes; London-wide ULEZ avoid is ORS area-cap blocked. Residual: `EPIC-LEZ-CADASTRE`.
- **Tolls** — named UK £ advisories + one-shot commit TTS + iOS/Android in-nav toll HUD + ORS avoid-tolls replan; Mac/web desk show corridor indicative £ (including M6 / Dartford / Tyne + Mersey £4.80 + Dunham £4.00 + Batheaston HGV-unsuitable). **Not** live operator / class tariffs — residual `EPIC-TOLL-DEPTH`.
- **Hazards** — on-device crowd reports (iOS + Android C2) fused with TomTom live ahead, MapLibre pins, and still-there confirm; OSM roadworks enter the predictive fuse when Overpass proxy is configured.
- **Laybys / parking** — ranked green/amber/red map pins, occupancy taps with age-weighted priors (“Looks full” / “Has spaces”), Break Now; Mac/web `predictedLayby` card/pin + Android snapshot publish. Residual: live bay counts / partner occupancy feed. Booking remains deep-link + voice entry (not native partner book API).

### Compliance and HOS

Hours of service are **advisory**: EU Regulation 561 / Working Time Directive clock, rest insertion suggestions, driver-card JSON/DDD import, and “Can I drive now?” (day + week) on cab and desk. Walkaround checks follow a local DVSA-style checklist with snapshot / PDF / photos on Android C2 parity slices.

**The VU / digital tachograph is authoritative.** Remote legal VU download is residual (`EPIC-VU-PARTNER`); desk Can-I-drive week cards and CSV stubs are planning aids only.

### Lane guidance and voice

OSM `turn:lanes` strip + street/lane TTS with prepare re-speak when Overpass upgrades heuristic→OSM inside the prepare window (iOS + Android C2; Overpass capped ≤12 / route, STRAIGHT skip, ~50 km). Domain PTT covers which-lane / avoid-tolls / layby / hazard / book parking / Can-I-drive. **Not** HD lane visuals — residual `EPIC-LANE-DEPTH`.

---

## 5. Competitive posture

*(Stub — fill after Ch 4.)*

- Summarize Lead / Parity / Gap from [`competitive-feature-scorecard.md`](competitive-feature-scorecard.md) without inventing brochure claims.
- List gated residuals: CarPlay prod, Android Auto, VU partner, live toll £, HD lanes, Stripe, country PBF / Android offline.
- Sweep runbook: [`ultimate-competitive-excellence-sweep.md`](ultimate-competitive-excellence-sweep.md).
- Personas weight: [`buyer-personas-uk-hgv.md`](buyer-personas-uk-hgv.md) when present.

---

## 6. Architecture and repo layout

*(Stub — fill after Ch 5.)*

- Module / coordinator story: [`architecture.md`](architecture.md).
- Thin index (layout, tests, hard rules): [`developer-map.md`](developer-map.md).
- Packages: `RouteFinder/`, `RouteFinderApp.xcodeproj`, `web-dispatch/`, `hosted-gateway/`, `android-fleet-driver/`, `Docs/`.
- UI glass: `GlassmorphicModifiers`; Swift strict concurrency; never commit unmasked keys.

---

## 7. Operator / pilot path

*(Stub — fill after Ch 6.)*

- Stranger tests by role: [`getting-started.md`](getting-started.md).
- Pilot pack / outreach: [`pilot-fleet-pack.md`](pilot-fleet-pack.md), [`pilot-outreach.md`](pilot-outreach.md).
- Optional physical smoke: [`phase1-device-checklist.md`](phase1-device-checklist.md).
- Feedback backlog: [`pilot-feedback-backlog.md`](pilot-feedback-backlog.md).

---

## 8. Open gates and non-goals

*(Stub — fill after Ch 7.)*

- **Gated:** `EPIC-ANDROID-AUTO` / offline packs, `EPIC-CARPLAY-PROD`, `EPIC-VU-PARTNER`, live toll £, HD lane visuals, Stripe billing, further country PBF.
- **Anti-grind:** no mid-corridor / LEZ densify / toll-£ clones unless Mersey-class catalog hole or measurable scorecard gap; no unbounded London ULEZ avoid PRs (ORS area caps).
- **Non-goals:** full SaaS billing UI; multi-surface crowd LAN invent; claiming legal cadastre or live operator tariffs without feeds.
- When product gates stay locked, agents continue this writeup’s next unfinished chapter instead of STOP-looping.

---

## 9. Changelog of writeup iterations

| Date | PR / issue | Chapters |
|------|------------|----------|
| 2026-11-11 | #125 / #126 | Scaffold ToC 1–9; draft Ch 1–3; stub Ch 4–8 |
| 2026-11-11 | #127 / (this PR) | Draft Ch 4 (routing / UK living layer / compliance); next = Ch 5 |
