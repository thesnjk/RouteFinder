# Competitive Feature Scorecard — September 2026

Last updated: 2026-09-15 (Phase 8 competitive parity extras)

Scoring: **0** Absent · **1** Weak · **2** Parity · **3** Lead  
Personas: **OO** = UK owner-operator · **SF** = small fleet (2–20 vehicles)

RouteFinder scores from code inventory + Phase 20/26/27/30–44 + **Phase 8** verification. Competitor scores from public sources only (`.firecrawl/`).

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
| LEZ compliance | 8% | **2** | 3 | 3 | 2 | 2 | RF 11 zones |
| Lane guidance | 8% | **2** | 3 | 3 | 2 | 2 | RF OSM + nav refresh (Ph8) |
| Plate → profile (UK) | 8% | **3** | 0 | 0 | 0 | 0 | RF RegCheck + DVLA |
| Crowd hazard / closure ahead | 5% | **2** | 1 | 1 | 0 | 0 | RF Ph33 + Ph36 TomTom live |
| UK toll awareness | 5% | **1** | 2 | 3 | 2 | 2 | RF named hints (Ph8); TomTom tariffs lead |
| Telematics / tacho display | 5% | **1** | 1 | 1 | 2 | 1 | RF CSV stub (Ph8); Samsara VU elsewhere |
| Price ($0 baseline) | 5% | **3** | 1 | 1 | 0 | 1 | RF $0; CoPilot quote-only |

**Weighted OO score (approx.):** RouteFinder **~2.48** · Sygic **~2.00** · TomTom **~2.20** · CoPilot **~1.80**  
(Incremental Phase 8; not full parity — footnote.)

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
| Price | 10% | **3** | 0 | 0 | 0 | RF $0 vs per-seat SaaS |

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
