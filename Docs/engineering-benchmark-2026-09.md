# Engineering benchmark — September 2026

**Track:** Engineering excellence Phase 1 (no legal/GTM).  
**ICP:** UK independents, **5–15 trucks**, iPhone-first dispatch + driver wedge.  
**Sources:** [`competitive-gap-matrix.md`](competitive-gap-matrix.md), [`competitive-feature-scorecard.md`](competitive-feature-scorecard.md), [`competitive-research-2026-08.md`](competitive-research-2026-08.md), [`competitor-pricing-2026.md`](competitor-pricing-2026.md) (pricing cited only for competitor capability context, not sales).  
**Last updated:** 2026-09-18

Scoring per row for **RouteFinder vs best of four phone/hardware nav peers:**

| Label | Meaning |
|-------|---------|
| **Lead** | RouteFinder clearly ahead on ICP-relevant behavior (code shipped + doc evidence) |
| **Parity** | Comparable for demo; minor depth gap acceptable |
| **Gap** | Competitor materially ahead; needs epic or intentional non-parity |

---

## Benchmark matrix

| Capability | CoPilot Truck | Sygic Truck | TomTom GO Pro | Garmin dēzl OTR | RouteFinder | RF vs field | Evidence |
|------------|:-------------:|:-----------:|:-------------:|:---------------:|:-----------:|:-----------:|----------|
| **HGV constraint routing** (L/W/H, hazmat, avoids) | Parity | Parity | Parity | Parity | **Lead** (ORS + offline hybrid policy) | **Parity→Lead** | `OpenRouteServiceRoutingClient`, `DiskOfflineGraphStore`, scorecard OO row 1 |
| **Physics rehearsal / kinetic ETA** | Absent | Absent | Absent | Absent | **Lead** | **Lead** | `RouteSimulationCoordinator`, Rehearse UX, `TripBriefContext`, gap matrix white space §1 |
| **Dispatch desk** (push trip, desk UX) | Strong (Account Manager SaaS) | Weak | Weak | Weak | **Lead** (native Mac/iPad + web LAN) | **Lead** (ICP) | `DispatchConsoleView`, `web-dispatch/`, `FleetSSEClient`, scorecard SF dispatch 3 |
| **Fleet API surface** (trips, SSE, snapshot, proxy) | Enterprise | Weak | Weak | Weak | **Lead** (documented REST + hosted parity) | **Lead** | `FleetRouterBuilder`, `hosted-gateway/`, README fleet LAN |
| **Offline UK** (maps + routing corridor) | Parity | **Lead** | **Lead** | **Lead** | Parity | **Gap** | `OfflineMapPackStore`, `OfflineDownloadRegion`, Ph8 progress UX — not planet PBF |
| **Lane guidance** (junction) | Parity | **Lead** | **Lead** | Weak | Parity (OSM + nav refresh) | **Gap** | `LaneGuidanceEnricher`, `OverpassLaneGuidanceClient`, Ph8 cap 12 — below TomTom HD |
| **CarPlay / Android Auto** | AA shipped | CarPlay IAP | Hardware-native | Hardware | Code ready; **entitlement gap** | **Gap** | `CarPlayNavigationCoordinator`, `carplay-weatherkit-restore.md` |
| **Android driver** (fleet + nav) | Strong fleet Android | App only | Hardware | Hardware | **Gap** (C2 in progress) | **Gap** | `android-fleet-driver/`, `phase6b-android-nav-verification.md`, `android-c2-gate.md` |
| **Telematics / live map** | ELD + fleet | Weak | Weak | Weak | Stub only | **Gap** | `TelematicsCSVImporter`, `POST /v1/telematics/ingest` — intentional non-VU |
| **Toll awareness** | Tariffs + avoid | Parity | **Lead** | Parity | Hints only | **Gap** | `UKTollAdvisoryCatalog`, `TollAdvisoryAlongRouteMatcher` — intentional non-tariff |
| **LEZ / CAZ** | Parity | **Lead** (avoid depth) | **Lead** | Parity | Parity (11 zones, avoid) | **Parity** | `UKLowEmissionZoneBoundaries`, `LEZAvoidPolicy` — simplified rings |
| **Layby / break intelligence** | HOS + TRAVIS book | Weak | Weak | Community parking | **Lead** | **Lead** | `LaybyPredictionEngine`, Break Now Ph30, `ParkingPartnerLinks` |
| **Stranger / zero driver keys** | Fleet-managed | User keys | Device | Device | **Lead** (fleet ORS proxy) | **Lead** | `FleetORSRoutingFactory`, `FleetProxyUsageMeter`, staged Ph2 |

**Gate check:** 4 competitors × 12 capability rows — **pass**.

---

## RouteFinder Lead / Parity / Gap summary (engineering view)

| Status | Count | Capabilities |
|--------|------:|----------------|
| **Lead** | 6 | Physics rehearsal, dispatch desk, fleet API, layby/break, stranger+fleet proxy, UK plate→profile (see scorecard) |
| **Parity** | 2 | HGV constraints (vs top apps), LEZ stack |
| **Gap** | 6 | Offline depth, lane HD, CarPlay/AA production, Android C2 maturity, telematics live map, toll tariffs |

---

## Gap → engineering epic (or intentional non-parity)

| Gap | Epic ID | Action |
|-----|---------|--------|
| Offline vs Sygic/TomTom/Garmin | `EPIC-OFFLINE-UX` | Phase 3/6: corridor reliability, download UX, hybrid policy tuning — **not** in-app planet PBF (`competitive-gap-matrix.md` remaining gaps) |
| Lane vs TomTom/Sygic HD | `EPIC-LANE-DEPTH` | Incremental OSM + nav refresh (Ph8 done); further chase only if pilot proves junction misses — else **intentional non-parity** |
| CarPlay / AA | `EPIC-CARPLAY-PROD` | Paid-team entitlements + device QA (`phase5-carplay-verification.md`) — **not** AA in near term |
| Android driver | `EPIC-ANDROID-C2` | Close `phase6b` + `android-c2-gate.md` before mixed-fleet demos |
| Telematics live map | `EPIC-TELEMATICS-STUB` | **Intentional non-parity** — read-only CSV/ingest only; no VU SDK |
| Toll tariffs | `EPIC-TOLL-HINTS` | **Intentional non-parity** — authored hints only (`UKTollAdvisoryCatalog`) |
| Device P0 / regressions | `EPIC-P0-DEVICE` | `phase20-verification.md` C1–C9 + Part B — blocks “bug-free demo” claim |
| Stranger path polish | `EPIC-STRANGER-UX` | Role picker → fleet wizard → Start Navigation without driver ORS key |

Every **Gap** row maps to exactly one row above — **pass**.

---

## Top 5 epics (ICP order: UK 5–15 trucks, iPhone-first)

| Rank | Epic | Why first | Competitive edge (one line) |
|------|------|-----------|------------------------------|
| **1** | `EPIC-P0-DEVICE` | No benchmark matters if C1–C9 / Part B fail on real hardware | vs CoPilot desk demos: **same push→nav→snapshot pin script works on operator LAN without cloud portal setup** — only if device gate is green (`phase20-verification.md`) |
| **2** | `EPIC-STRANGER-UX` | Fleet proxy is shipped; friction is still onboarding clicks | vs Sygic: **driver never creates HeiGIT account** when desk runs `--ors-key`; vs CoPilot: **fewer portal steps** — role + QR vs Account Manager seat provisioning (`LaunchRole`, `FleetSetupWizardView`) |
| **3** | `EPIC-CARPLAY-PROD` | In-cab is table stakes for some independents with newer tractors | vs Sygic CarPlay IAP: **included in app** once entitled — vs hardware TomTom: **no separate sat-nav box** for trip handoff (`CarPlayNavigationCoordinator`) |
| **4** | `EPIC-ANDROID-C2` | Mixed fleets block deals without a credible Android driver | vs CoPilot-only Android: **same fleet SSE + ORS proxy contract** as iOS — one server, two clients (`android-fleet-driver/fleet/FleetApi.kt`) |
| **5** | `EPIC-OFFLINE-UX` | Eastern UK / poor depot Wi‑Fi still hurts vs Sygic offline reputation | vs Sygic: **corridor H3 + region picker + progress** — honest smaller footprint, faster to download than full country (`DiskOfflineGraphStore.ensureCorridor`, Ph8 `OfflineDownloadRegion`) |

Lower priority (defer unless pilot signal): `EPIC-LANE-DEPTH` chase, telematics beyond stub, toll tariffs, hosted billing UI.

---

## Module competitive edge (demo script hooks)

| Module | vs market | Measurable hook |
|--------|-----------|-----------------|
| Rehearse + physics ETA | CoPilot / Sygic / TomTom / Garmin — none ship pre-trip kinetic sim | Rehearse completes → trip brief ETA updates before wheel rolls |
| Dispatch + SSE | CoPilot Account Manager — cloud seat | LAN toast **&lt;10 s** after push (Phase 3 gate) |
| Trip brief + PDF + inspection | Fleet SaaS — strong on compliance, weak on physics narrative | Walkaround defect on brief + dispatch card (`DispatchStatusPanel`) |
| Fleet ORS proxy | Per-driver API keys in consumer apps | `GET /v1/proxy/status` shows caps; driver app routes without local ORS key |
| Layby + Break Now | CoPilot TRAVIS booking path | **$0** OSM layby rank + partner **links** only — faster “where to stop” without checkout |
| Hosted gateway | PTV / enterprise hosted | Same `/v1/*` as LAN — remote depot without rewriting clients (`hosted-gateway-deployment.md`) |

---

## Phase 1 quality gate

- [x] Table covers ≥4 competitors (CoPilot, Sygic, TomTom GO Pro, Garmin dēzl)
- [x] ≥10 capability rows (12 listed)
- [x] Every Gap maps to epic or intentional non-parity
- [x] Top 5 epics ordered for ICP with one competitive-edge line each
- [x] No legal/pilot/GTM content in this doc

**Next engineering phase:** Engineering excellence track **complete** through Phase 7 (P0 simulator consolidation). Remaining: operator-owned device QA (C4 layby voice, C9 TomTom, Fleet Part B LAN, CarPlay head unit, Android Norwich corridor); maintenance only.
