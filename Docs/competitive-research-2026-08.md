# Competitive Research — August 2026

Date: 2026-08-28  
Scope: UK/EU HGV navigation for **owner-operators** and **small fleets (2–20 vehicles)**  
Methodology: Public product pages, App Store listings, Trimble release notes, TRAVIS press (Jul 2026), Sygic help articles. Archived summaries in `.firecrawl/` (not committed).

**Explicitly out of scope for this push:** CarPlay entitlements, WeatherKit, Android Auto, hosted multi-tenant SaaS, remote VU download, paid fuel/SNAP APIs, legal cadastral LEZ polygons.

**Phase 29 refresh (2026-08-28):** Positioning update only — no new competitor scrape. Narrative updated to reflect Ph26–27 shipped capabilities.

---

## Executive summary

RouteFinder holds a defensible wedge on **physics rehearsal**, **$0 fleet LAN dispatch**, **UK plate→profile**, and **driver/fleet polish** (onboarding, map label i18n, scripted fleet QA) — but is not universal parity with Sygic, TomTom hardware, or CoPilot fleet seats.

**Current wedge vs Sygic / TomTom / CoPilot (post Ph26–27):**

1. **Physics rehearsal + layby prediction** — Pre-trip kinetic sim, fused HOS/company-break ranker, and **Break Now** quick action at $0 (CoPilot charges for TRAVIS booking; TomTom/Sygic lack physics rehearsal).
2. **$0 fleet LAN dispatch** — Bonjour discovery, SSE push, physics ETA, trip brief PDF; scripted E2E QA playbook ([`fleet-e2e-qa.md`](fleet-e2e-qa.md)) vs per-seat Account Manager SaaS.
3. **UK plate→profile + honest LEZ messaging** — RegCheck + DVLA chain; 11 authored zones with Euro-class copy (simplified geometry, not legal cadastre).
4. **Driver onboarding + map label i18n** — First-launch product sheet and separate MapLibre label language picker for EU small-fleet drivers.

**Wave 1 shipped (Phase 26):** Break Now HUD button, LEZ catalog expansion (11 zones) + honest Euro copy, lane voice at prepare/execute tiers.

**Wave 2 shipped (Phase 27):** Product onboarding sheet, map label language preference (independent of UI locale), fleet E2E scripted QA (`fleet-e2e-smoke.sh` + SSE snapshot test).

**Remaining $0 gaps (honest, not chasing unless UK wedge):** LEZ depth (2 vs Sygic/TomTom 3), lane guidance depth (2 vs 3), CarPlay/Android Auto (deferred — paid team).

**Intentional deferrals (document, do not chase):** TRAVIS/TPC paid parking booking, CarPlay/Android Auto, remote VU, toll tables, legal LEZ cadastre, hosted fleet portal.

---

## Post-Phase-27 positioning (sales lines)

**Owner-operator (1 vehicle):**

- Rehearse your route with real vehicle physics before you roll — no other truck nav app does this at $0.
- Break when you need to: fused layby prediction plus one-tap **Break Now**, without TRAVIS booking fees.
- UK plate lookup builds your profile; LEZ banners and avoid-on-route with honest Euro-class copy.

**Small fleet (2–20 vehicles):**

- Push trips over your office LAN — Bonjour discover, SSE instant notify, physics ETA back to dispatch — no per-seat SaaS.
- Trip brief PDF for the office; drivers get onboarding and map labels in their preferred language.
- Scripted fleet QA (`./Scripts/fleet-e2e-smoke.sh`) proves push → rehearse → brief without a hosted portal.

---

## Methodology

| Step | Action |
|---|---|
| A1 | Scrape/archive 8 competitor/regulatory source packs → `.firecrawl/*.md` |
| A2 | Score capabilities 0–3 (Absent / Weak / Parity / Lead) per persona weights |
| A3 | Rank gaps: `(competitor lead − RouteFinder) × weight × feasibility` |
| A4 | Ship top 2–3; verify in Phase 26 live QA checklist |

Sources dated 2026-08-27/28 unless noted. Firecrawl CLI unavailable in-session; WebFetch + WebSearch used instead.

---

## Key deltas since Phase 20 (Aug 2026)

| Competitor | New / clarified capability | RouteFinder response |
|---|---|---|
| **CoPilot 11.3** | Break Now (coffee-cup); default-on; 50k+ taps (May 2026) | Phase 26 Break Now quick action |
| **CoPilot + TRAVIS** | 750+ EU parking sites, booking redirect (Jul 23 2026) | Document deferral — no booking fee parity |
| **Sygic Truck** | LEZ profile + reroute; fuel prices; CarPlay paid add-on | LEZ v2 copy + zone expansion; CarPlay deferred |
| **TomTom GO Pro** | LEZ avoid on NDS hardware; lane guidance | Lane voice polish; honest LEZ geometry disclaimer |
| **Garmin dēzl** | Community parking ratings (hardware) | Layby occupancy taps remain $0 wedge |

---

## Persona snapshot

### UK owner-operator (1 vehicle)

- **Jobs:** Long-haul constrained routing, mandatory breaks, LEZ compliance, offline when signal poor.
- **Defaults today:** Sygic Truck (offline + LEZ) or CoPilot if fleet-affiliated.
- **RouteFinder wins:** Physics rehearsal, layby prediction + Break Now without booking fees, UK plate lookup, onboarding sheet, map label i18n, $0 app.
- **RouteFinder gaps (honest):** LEZ/lane depth vs Sygic/TomTom, CarPlay (deferred on personal team).

### Small fleet (2–20 vehicles, UK)

- **Jobs:** Push trips to drivers, physics ETA to depot, trip brief for office, LAN without per-seat SaaS.
- **Defaults today:** CoPilot Account Manager + telematics (Samsara/Geotab) or TomTom WEBFLEET add-ons.
- **RouteFinder wins:** $0 Bonjour LAN + SSE dispatch, trip brief PDF, physics ETA on push, fleet E2E QA playbook, driver onboarding.
- **RouteFinder gaps:** Hosted portal, remote VU, TRAVIS parking network, Android Auto.

---

## Sources

- [Sygic Truck](https://www.sygic.com/truck) · [Sygic LEZ](https://www.sygic.com/what-is/low-emission-zones)
- [TomTom GO Professional](https://www.tomtom.com/en_gb/navigation/truck-gps-sat-nav/go-professional/)
- [CoPilot 11 introduction](https://developer.trimblemaps.com/copilot-navigation/release-notes/introduction-copilot-11/)
- [TRAVIS × Trimble press](https://www.yourtravis.com/knowledge/trimble-integration/) (2026-07-23)
- [Garmin dēzl OTR press](https://www.garmin.com/en-US/newsroom/press-release/automotive/garmin-introduces-refreshed-dezl-otr-navigator-series-with-insights-from-fellow-truck-drivers/)
- [PTV Navigator](https://www.ptvlogistics.com/en-us/products/ptv-navigator/features)
- [HERE Pro Nav](https://www.here.com/solutions/professional-navigation)
- [Samsara UK tachograph](https://www.samsara.com/uk/products/telematics/tachograph)
- [Geotab digital tachograph](https://www.geotab.com/uk/fleet-management-solutions/smart-digital-tachograph/)

See also: [`competitive-feature-scorecard.md`](competitive-feature-scorecard.md), [`competitor-pricing-2026.md`](competitor-pricing-2026.md), [`buyer-personas-uk-hgv.md`](buyer-personas-uk-hgv.md).
