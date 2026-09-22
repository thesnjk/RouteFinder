# Android C2 gate — full HGV navigator

Full Android navigation beyond the shipped C2 MVP (offline graph, Android Auto) remains a **multi-month** Kotlin program for the deepest parity items. Split product prioritization from engineering parity below.

Last updated: 2026-09-22 (U12–U15 Done; next = product-gated offline / Android Auto)

---

## Status — two gates

### Product prioritization gate (pilots)

**LOCKED** for *further* C2 depth that is still pilot-gated as product priority (Android Auto, offline packs). Zero paying renewals blocked by Android in [`pilot-feedback-backlog.md`](pilot-feedback-backlog.md). Do **not** prioritize Android Auto / offline until ≥2 renewals cite Android drivers.

Related mid-market items (also pilot-gated for *priority*):

| Signal | Build only when |
|--------|-----------------|
| Android drivers block renewal | Product gate unlocks Android Auto / offline packs |
| Remote depot (no LAN) | Hosted relay after VPN guide fails for ≥2 pilots |
| Trucks on a map | Periodic GPS if ≥2 fleets demand |
| CarPlay production device QA | Paid Apple Developer team + demand |

### Engineering parity gate (Phase 4)

**OPEN for MVP.** C2 MVP + U10–U15 are in-tree and verified by automated CI + [`phase6b-android-nav-verification.md`](phase6b-android-nav-verification.md).

| Criterion | How to verify | Status |
|-----------|---------------|--------|
| Fleet ORS proxy HGV routing (no driver HeiGIT key) | `FleetOrsConfig` + unit tests; phase6b exit gate | **Shipped** |
| MapLibre map + metric voice TBT | `android-fleet-driver` nav/voice modules | **Shipped** |
| SSE trip handoff + GPS snapshot | Same `/v1/*` as iOS LAN/hosted | **Shipped** |
| Physics rehearsal (grade ETA) | `RouteRehearsalEngine` + unit tests | **Shipped** |
| Job intake RegCheck + ADR→ORS hazmat | `RegCheckClient` + wizard/nav RegCheck username field + unit tests | **Shipped** (U10) |
| Time windows on job brief + late-ETA fuse | `StopTimeWindow` parse + `TimeWindowRiskEvaluator` → fuse banner | **Shipped** (U11) |
| Predictive risk primary banner (kinetic / traffic / hazard / schedule / forecast / clearance) | `PredictiveRiskEngine` + `ForecastRiskSampler` + `ClearanceCorridorProbe` | **Shipped** (U10 + U11) |
| DVSA walkaround → snapshot + PDF / photos | `InspectionWalkaroundDialog` + `InspectionReportPdfRenderer` | **Shipped** (U12) |
| LEZ / HOS / layby advisory | `UkLezCatalog` + `HosAdvisoryClock` + `LaybyAdvisoryEngine` | **Shipped** (U13) |
| Fleet TomTom / OpenWeather / Overpass proxy | `FleetForecastProxy` + Android clients via `FleetOrsConfig` | **Shipped** (U14) |
| Off-route heading clearance | `ClearanceCorridorProbe.isOffRoute` + heading corridor | **Shipped** (U14b) |
| ORS LEZ `avoid_polygons` when avoid toggle on | `LezAvoidPolicy` + `OrsDirectionsRequest` | **Shipped** (U15) |
| CI green | `.github/workflows/ci.yml` `android-c1` job | **Pass** |
| Device QA Norwich corridor | phase6b checklist | **Pending local (operator)** |

Engineering excellence Phase 4 closes when CI is green and phase6b is either Pass or documented Pending with owner — see [`phase4-platform-parity-verification.md`](phase4-platform-parity-verification.md).

---

## Product gate criteria (all required to prioritize Android Auto / offline packs)

| # | Criterion | How to verify |
|---|-----------|---------------|
| 1 | **≥2 paying / renewing pilots** say they cannot renew or expand because drivers are on Android | Rows in [`pilot-feedback-backlog.md`](pilot-feedback-backlog.md) + pricing log |
| 2 | **Android C1/C2** fleet client works on LAN (SSE + snapshot) with those fleets | [`../android-fleet-driver/README.md`](../android-fleet-driver/README.md) |
| 3 | **Web or Mac dispatch** can push trips to mixed iOS + Android drivers | Web: [`../web-dispatch/`](../web-dispatch/) |
| 4 | Written decision: **greenfield Kotlin** vs **routing microservice** (thin Android client) | Record below — **chosen:** greenfield Kotlin |

---

## Evidence log

| Date | Pilot | Blocks renewal? | Notes |
|------|-------|-----------------|-------|
| | | yes / no | |

**C2 product unlock date:** _not yet_

**Chosen C2 approach:** greenfield Kotlin (fleet ORS proxy client) — see Implementation status below

---

## What C2 is NOT

- Android Auto (deferred until phone nav works + product gate)
- Hosted SaaS requirement
- Feature parity day-one with every iOS polish item

---

## Next C2 milestones

1. Offline graph/tiles on device (product-gated)
2. Android Auto after phone nav is stable (product-gated)
3. Operator device QA: [`phase6b-android-nav-verification.md`](phase6b-android-nav-verification.md)

**Done (2026-09-22):** U12 walkaround PDF/photos · U13 LEZ/HOS/layby advisory · U14 forecast/clearance fleet proxy · U14b off-route clearance · **U15** ORS `avoid_polygons` via [`LezAvoidPolicy`](../android-fleet-driver/app/src/main/java/com/routefinder/fleetdriver/compliance/LezAvoidPolicy.kt).

**Implementation status (2026-09-22):** C2 MVP + U10–U15 landed in [`../android-fleet-driver/`](../android-fleet-driver/) (fleet proxy routing, MapLibre, metric TTS, SSE handoff, grade rehearsal, RegCheck, time windows, predictive fuse, walkaround PDF, compliance advisory + LEZ avoid rings). Device QA: [`phase6b-android-nav-verification.md`](phase6b-android-nav-verification.md).

**Chosen C2 approach:** greenfield Kotlin in-app navigator (thin client calling office fleet ORS/Pelias proxy).
