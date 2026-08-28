# Competitive Feature Scorecard — August 2026

Last updated: 2026-08-29 (Phase 41–42 dispatch inspection visibility + CI)

Scoring: **0** Absent · **1** Weak · **2** Parity · **3** Lead  
Personas: **OO** = UK owner-operator · **SF** = small fleet (2–20 vehicles)

RouteFinder scores from code inventory + Phase 20/26/27/30–42 verification. Competitor scores from public sources only (`.firecrawl/`).

---

## Owner-operator weights

| Capability | Weight | RF | Sygic | TomTom HW | CoPilot 11 | Garmin | Notes |
|---|---:|---:|---:|---:|---:|---:|---|
| Constraint routing (L/W/H/hazmat) | 20% | **3** | 2 | 3 | 3 | 3 | RF ORS + offline hybrid |
| Offline UK maps | 15% | **2** | 3 | 3 | 2 | 3 | RF corridor packs; Sygic multi-country |
| Physics rehearsal | 15% | **3** | 0 | 0 | 0 | 0 | RF wedge |
| Layby / break intel | 15% | **3** | 1 | 2 | 2 | 2 | RF fused ranker + Break Now + voice (Ph26/30) |
| LEZ compliance | 10% | **2** | 3 | 3 | 2 | 2 | RF 11 zones; Sygic/TomTom deeper |
| Lane guidance | 10% | **2** | 3 | 3 | 2 | 2 | RF OSM + voice polish (Ph26) |
| Plate → profile (UK) | 10% | **3** | 0 | 0 | 0 | 0 | RF RegCheck + DVLA |
| Crowd hazard / closure ahead | 5% | **2** | 1 | 1 | 0 | 0 | RF Ph33 crowd + **Ph36 TomTom live**; Waze deeper |
| Price ($0 baseline) | 5% | **3** | 1 | 1 | 0 | 1 | RF $0; CoPilot quote-only |

**Weighted OO score (approx.):** RouteFinder **2.55** · Sygic **2.05** · TomTom **2.15** · CoPilot **1.85**

---

## Small-fleet weights

| Capability | Weight | RF | CoPilot AM | PTV | Samsara | Notes |
|---|---:|---:|---:|---:|---:|---|
| Dispatch push | 20% | **3** | 2 | 2 | 3 | RF SSE + native console + walkaround PDF + dispatch defect card (Ph39–41) |
| Physics ETA to depot | 15% | **3** | 1 | 2 | 2 | RF wedge |
| Trip brief PDF | 15% | **3** | 1 | 2 | 2 | RF shipped Ph15; defect warning line Ph39 |
| LAN sync / Bonjour | 15% | **3** | 0 | 1 | 0 | RF $0 LAN |
| Layby on trip | 10% | **3** | 2 | 1 | 0 | RF prediction + Break Now |
| Constraint routing | 10% | **3** | 3 | 3 | 2 | Parity |
| Auth/TLS fleet server | 10% | **2** | 3 | 3 | 3 | RF API key + optional TLS |
| Price | 5% | **3** | 0 | 0 | 0 | RF $0 vs per-seat SaaS |

**Weighted SF score (approx.):** RouteFinder **2.85** · CoPilot AM **1.65** · PTV **1.90** · Samsara **1.75** (nav slice only)

---

## Gap ranking (Phase 26 decision)

Formula: `(competitor best − RF) × persona weight × feasibility ($0, no CarPlay)`

| Rank | Gap | OO gap×wt | SF gap×wt | Feasibility | **Build?** |
|---:|---|---:|---:|---|---|
| 1 | Break Now UX | 0.15 | 0.05 | High | **Yes — Ph26** |
| 2 | LEZ v2 copy + coverage | 0.10 | 0.02 | High | **Yes — Ph26** |
| 3 | Lane voice + banner | 0.10 | 0.02 | High | **Yes — Ph26** |
| 4 | Fleet E2E hardening (docs) | 0.02 | 0.12 | Medium | **Done — Ph27c** ([`fleet-e2e-qa.md`](fleet-e2e-qa.md)) |
| 5 | Map label i18n | 0.03 | 0.04 | Medium | **Done — Ph27b** |
| 6 | Driver onboarding sheet | 0.05 | 0.03 | High | **Done — Ph27a** |

**Confirmed wave 1:** B1 Break Now · B2 LEZ v2 · B3 Lane voice (matches pre-research hypothesis).  
**Phase 27 wave:** onboarding · map label i18n · fleet E2E QA playbook — **complete**.  
**Phase 29:** Positioning refresh only; no new $0 builds ranked until next quarterly review (target **2026-11**). Ph27 capability pointers: [`ProductOnboardingSheet.swift`](../RouteFinder/Sources/UI/Components/ProductOnboardingSheet.swift), [`MapLibreMapHTML.swift`](../RouteFinder/Sources/UI/Map/MapLibreMapHTML.swift) (`setMapLabelLanguage`), [`fleet-e2e-qa.md`](fleet-e2e-qa.md).

---

## Intentional non-parity (sales honesty)

| Capability | Best-in-class | RouteFinder stance |
|---|---|---|
| CarPlay / Android Auto | Sygic / CoPilot | Deferred — personal-team entitlements |
| Paid parking booking (TRAVIS/TPC) | CoPilot + TRAVIS | Deferred — $0 wedge is prediction not booking |
| Remote VU download | Samsara / Geotab | Partner boundary — advisory tacho only |
| Legal LEZ cadastre | Sygic / TomTom | Simplified authored rings + honest disclaimer |
| Hosted multi-tenant SaaS | CoPilot Account Manager | LAN dispatch at $0 instead |
| Toll tariff tables | PTV / TomTom | Deferred |
