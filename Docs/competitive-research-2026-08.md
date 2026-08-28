# Competitive Research — August 2026

Date: 2026-08-28  
Scope: UK/EU HGV navigation for **owner-operators** and **small fleets (2–20 vehicles)**  
Methodology: Public product pages, App Store listings, Trimble release notes, TRAVIS press (Jul 2026), Sygic help articles. Archived summaries in `.firecrawl/` (not committed).

**Explicitly out of scope for this push:** CarPlay entitlements, WeatherKit, Android Auto, hosted multi-tenant SaaS, remote VU download, paid fuel/SNAP APIs, legal cadastral LEZ polygons.

---

## Executive summary

RouteFinder holds a defensible wedge on **physics rehearsal**, **$0 fleet LAN dispatch**, and **UK plate→profile** — but is not universal parity with Sygic, TomTom hardware, or CoPilot fleet seats.

After Aug 2026 research, the highest-ROI gaps to close at **$0 recurring cost** are:

1. **Break Now layby workflow** — CoPilot 11.3 ships one-tap break search by default; RouteFinder had fused layby prediction but no explicit driver-initiated quick action.
2. **LEZ v2 messaging + coverage** — Sygic/TomTom set expectations for broad UK zone awareness and clear Euro-class copy; RouteFinder had six authored rings but thin compliance messaging.
3. **Lane guidance voice polish** — TomTom/Sygic lane assistant is table-stakes; RouteFinder had banner + execute-tier voice but weak multi-lane phrasing and no prepare-tier lane hint.

**Wave 1 shipped (Phase 26):** Break Now HUD button, LEZ catalog expansion (11 zones) + honest Euro copy, lane voice at prepare/execute tiers.

**Intentional deferrals (document, do not chase):** TRAVIS/TPC paid parking booking, CarPlay/Android Auto, remote VU, toll tables, legal LEZ cadastre, hosted fleet portal.

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
- **RouteFinder wins:** Physics rehearsal, layby prediction without booking fees, UK plate lookup, $0 app.
- **RouteFinder gaps (pre–Phase 26):** Break Now UX, lane voice depth, LEZ zone breadth/messaging, CarPlay.

### Small fleet (2–20 vehicles, UK)

- **Jobs:** Push trips to drivers, physics ETA to depot, trip brief for office, LAN without per-seat SaaS.
- **Defaults today:** CoPilot Account Manager + telematics (Samsara/Geotab) or TomTom WEBFLEET add-ons.
- **RouteFinder wins:** $0 Bonjour LAN + SSE dispatch, trip brief PDF, physics ETA on push.
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
