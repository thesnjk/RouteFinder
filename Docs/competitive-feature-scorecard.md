# Competitive Feature Scorecard — September 2026

Last updated: 2026-09-25 (Android desk PDF/ETA handoff; Fleet proxy 429 → 3; Price notes aligned with pilot-fleet-pack)

Scoring: **0** Absent · **1** Weak · **2** Parity · **3** Lead  
Personas: **OO** = UK owner-operator · **SF** = small fleet (2–20 vehicles)

RouteFinder scores from code inventory + Phase 20/26/27/30–44 + **Phase 8** + **Phase 6** + Ultimate HGV U12–U15 engineering verification. Competitor scores from public sources only (`.firecrawl/`).

---

## Phase 8 before / after (incremental — not full parity)

| Capability | Before | After | Notes |
|---|---:|---:|---|
| Toll awareness | **0** | **1** | Named UK advisories; **not** live tariffs |
| Telematics display | **0** | **1** | CSV + webhook stub; **not** remote VU |
| Parking partners | **1** | **2** | TRAVIS/SNAP deep links; **not** booking |
| Offline UX | **2** | **2** | Same capability; region picker + progress |
| Lane guidance | **2** | **2**† | OSM tag expansion + nav refresh; still below TomTom HD |

† Documented as ~2.5 internally for OSM refresh depth; scorecard stays integer **2** vs TomTom/Sygic **3**.

---

## Owner-operator weights

| Capability | Weight | RF | Sygic | TomTom HW | CoPilot 11 | Garmin | Notes |
|---|---:|---:|---:|---:|---:|---:|---|
| Constraint routing (L/W/H/hazmat) | 18% | **3** | 2 | 3 | 3 | 3 | RF ORS + offline hybrid |
| Offline UK maps | 12% | **2** | 3 | 3 | 2 | 3 | RF corridor packs + download UX (Ph8) |
| Physics rehearsal | 14% | **3** | 0 | 0 | 0 | 0 | RF wedge |
| Layby / break intel | 12% | **3** | 1 | 2 | 2 | 2 | RF fused ranker + Break Now + TRAVIS/SNAP links (Ph8) |
| LEZ compliance | 8% | **3** | 3 | 3 | 2 | 2 | RF 11 zones + ORS avoid (iOS rings; Android U15) |
| Lane guidance | 8% | **2** | 3 | 3 | 2 | 2 | RF OSM + nav refresh (Ph8) |
| Plate → profile (UK) | 8% | **3** | 0 | 0 | 0 | 0 | RF RegCheck + DVLA |
| Crowd hazard / closure ahead | 5% | **2** | 1 | 1 | 0 | 0 | RF Ph33 + Ph36 TomTom live |
| UK toll awareness | 5% | **1** | 2 | 3 | 2 | 2 | RF named hints (Ph8); TomTom tariffs lead |
| Telematics / tacho display | 5% | **1** | 1 | 1 | 2 | 1 | RF CSV stub (Ph8); Samsara VU elsewhere |
| Price ($0 baseline) | 5% | **3** | 1 | 1 | 0 | 1 | Pilot £0 / post-pilot API-included desk subscription ([`pilot-fleet-pack.md`](pilot-fleet-pack.md)); not per-seat cloud portal; CoPilot quote-only |

**Weighted OO score (approx.):** RouteFinder **~2.56** · Sygic **~2.00** · TomTom **~2.20** · CoPilot **~1.80**  
(U15 LEZ ORS avoid lifts RF LEZ row 2→3; not full competitor parity — footnote.)

---

## Small-fleet weights

| Capability | Weight | RF | CoPilot AM | PTV | Samsara | Notes |
|---|---:|---:|---:|---:|---:|---|
| Dispatch push | 18% | **3** | 2 | 2 | 3 | RF SSE + native console + hosted gateway |
| Physics ETA to depot | 14% | **3** | 1 | 2 | 2 | RF wedge |
| Trip brief PDF | 12% | **3** | 1 | 2 | 2 | RF shipped |
| LAN / hosted sync | 14% | **3** | 0 | 1 | 0 | RF $0 LAN + Phase 7 hosted |
| Layby on trip | 10% | **3** | 2 | 1 | 0 | RF prediction + partner links |
| Constraint routing | 10% | **3** | 3 | 3 | 2 | Parity |
| Auth/TLS fleet server | 8% | **2** | 3 | 3 | 3 | RF API key + optional TLS |
| Telematics ingest (read-only) | 4% | **1** | 2 | 2 | 3 | CSV + POST stub (Ph8) |
| Price | 10% | **3** | 0 | 0 | 0 | Pilot £0 / post-pilot API-included desk subscription ([`pilot-fleet-pack.md`](pilot-fleet-pack.md)); not per-seat cloud portal |

**Weighted SF score (approx.):** RouteFinder **~2.78** · CoPilot AM **~1.55** · PTV **~1.80** · Samsara **~1.70** (nav slice only)

---

## Gap ranking (Phase 26 decision — historical)

Formula: `(competitor best − RF) × persona weight × feasibility ($0, no CarPlay)`

| Rank | Gap | OO gap×wt | SF gap×wt | Feasibility | **Build?** |
|---:|---|---:|---:|---|---|
| 1 | Break Now UX | 0.15 | 0.05 | High | **Yes — Ph26** |
| 2 | LEZ v2 copy + coverage | 0.10 | 0.02 | High | **Yes — Ph26** |
| 3 | Lane voice + banner | 0.10 | 0.02 | High | **Yes — Ph26** |
| 4 | Fleet E2E hardening (docs) | 0.02 | 0.12 | Medium | **Done — Ph27c** |
| 5 | Map label i18n | 0.03 | 0.04 | Medium | **Done — Ph27b** |
| 6 | Driver onboarding sheet | 0.05 | 0.03 | High | **Done — Ph27a** |

**Phase 8 wave:** UK toll hints · telematics CSV/webhook stub · parking deep links · offline region progress · lane Overpass depth — **complete**. QA: [`phase8-parity-verification.md`](phase8-parity-verification.md).

---

## Engineering excellence — Phase 6 (performance + demo)

Engineering-only deltas (no GTM / pricing). Evidence: [`phase6-performance-verification.md`](phase6-performance-verification.md), [`demo-superiority-script.md`](demo-superiority-script.md).

| Capability | Before Ph6 | After Ph6 | Notes |
|---|---:|---:|---|
| Demo script (push → rehearse → pin → walkaround) | Doc scatter | **3** | One-take script with competitor callouts |
| Lane Overpass cost discipline | Cap shipped, unmeasured | **3** | Asserted ≤12 Overpass fetches / route find |
| Offline download progress correctness | UX present | **3** | Progress events == H3 cell count (tested) |
| Web dispatch map preview stability | Poll churn | **3** | Fingerprint skips timestamp-only updates |
| Fleet proxy 429 surfacing | Generic HTTP error | **3** | Explicit daily-cap copy on route + geocode (iOS / Android / web) |

Weighted OO/SF tables above are **unchanged** by Phase 6 (performance / honesty, not new capability rows).

---

## Ultimate HGV — predictive fuse & job brief (2026-09)

| Capability | iOS / macOS | Android C2 | Notes |
|---|---:|---:|---|
| Unified `RouteRiskAdvisory` fuse (kinetic / weather / hazard / roadworks / traffic) | **3** Lead | **3** (U11) | Primary HUD + voice dedup on Apple; Android fused banner + schedule/forecast/clearance |
| `FleetJobBrief` weight / ADR / auto-find on SSE push | **3** | **3** | Android ORS includes ADR→hazmat; time windows on status card (U11) |
| RegCheck on job intake (plate → dims) | **3** | **2** (U10) | Android RegCheck when username set (wizard + nav field) |
| DVSA walkaround + defect photos + PDF | **3** | **3** (U12) | Android gallery attach + local PDF + richer snapshot handoff |
| 1–3h traffic/weather forecast advisories | **2** (U8) | **3** (U11 + U14) | Fleet TomTom/OpenWeather proxy — zero driver forecast keys on Android |
| Off-route / corridor clearance radar | **3** (U9 + U11-B2) | **3** (U14b) | Android: on-route Overpass + heading corridor when off-spine |
| LEZ / CAZ ORS `avoid_polygons` | **3** | **3** (U15) | Android `LezAvoidPolicy` mirrors iOS area + long-haul caps |
| HOS clock + layby ahead | **3** | **2** (U13 MVP) | Android advisory clock + layby ahead; Apple keeps full coordinator depth |

† U12–U15 closed Android walkaround PDF, LEZ/HOS/layby advisory, fleet forecast/clearance proxy, off-route clearance, and ORS LEZ avoid. Residual: Android LEZ geometry is circle envelopes (iOS has hand-authored rings); optional U16 shared boundary asset.

---

## Intentional non-parity (sales honesty)

| Capability | Best-in-class | RouteFinder stance |
|---|---|---|
| CarPlay / Android Auto | Sygic / CoPilot | Paid-team CarPlay restore; Android Auto deferred |
| Paid parking booking (TRAVIS/TPC) | CoPilot + TRAVIS | Deep links only (Ph8) — prediction remains the $0 wedge |
| Remote VU download | Samsara / Geotab | Partner boundary — advisory tacho + CSV stub |
| Legal LEZ cadastre | Sygic / TomTom | Simplified authored rings + honest disclaimer |
| Hosted multi-tenant SaaS | CoPilot Account Manager | Hosted gateway + tokens; no billing UI |
| Toll tariff tables | PTV / TomTom | Named UK advisories only (Ph8) |
| Per-seat API burn visibility | Enterprise fleet SaaS | On-device ledger + soft budgets (Ph45) |
