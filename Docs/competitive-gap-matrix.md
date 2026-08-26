# HGV Navigation Competitive Gap Matrix

Last updated: 2026-08-26  
Strategy: global vision, **ship UK first**; differentiate on physics-sim + predictive telematics, then CarPlay parity, then fleet/dispatch, then advisory tacho + offline packs.

> Parallel API refresh was attempted via `parallel-cli` but the API was unreachable from this environment (`APIConnectionError`). This matrix is maintained from the competitive plan’s live web sources plus a post-implementation codebase inventory. Re-run Parallel when `api.parallel.ai` is reachable.

## Programme status (Phases 0–6)

| Phase | Focus | Status |
|---|---|---|
| **0** | Living-layer domain types (vector, crowd, layby, HOS/inspection/dock/alert) | **Done** |
| **1** | EU 561 advisory HOS clock + rest insertion + HUD | **Done** |
| **2** | Constraint parity, physics wedge, traffic/POI/fleet/inspection hardening | **Done** (inspections: local disk + glass checklist) |
| **3** | Offline H3 tile pipeline / graph store path | **Done** — `DiskOfflineGraphStore` + hybrid ORS/offline policy + tile scripts |
| **4** | Offline map packs in MapLibre WKWebView | **Done** — local HTTP pack server + bundled MapLibre preference |
| **5** | Advisory tacho — DDD/JSON import, Can-I-drive, partner stub | **Done** |
| **6** | Product hygiene — README, this matrix, glass surfaces | **Done** |

### Remaining gaps (explicitly not claiming parity)

- Full multi-country **toll tariff tables**
- **Remote VU download** (partner SDK — VDO / Stoneridge / Samsara)
- **Android Auto**
- **In-process planet PBF** parser (pipeline uses osmium + `PBFPreprocessor` / tile scripts instead)
- Paid live fuel-price API / SNAP booking
- Pre-built UK continent tile CDN hosting (app downloads packs; you still need to publish tiles)

## Competitor strengths (reference)

| Competitor | Form | Notable strengths |
|---|---|---|
| [Sygic Truck](https://www.sygic.com/truck) | Phone app | Offline maps; full dims; multi-stop; truck POIs; [CarPlay/AA](https://www.sygic.com/what-is/sygic-gps-truck-caravan-androidauto-carplay-us) |
| [TomTom GO Professional](https://www.tomtom.com/en_gb/navigation/truck-gps-sat-nav/go-professional/) | Hardware | L/W/H, axle, hazmat, ADR tunnels, LEZ avoid, truck POIs |
| [Garmin dēzl OTR](https://www.garmin.com/en-US/newsroom/press-release/automotive/garmin-introduces-refreshed-dezl-otr-navigator-series-with-insights-from-fellow-truck-drivers/) | Hardware | Truckstops/parking/weigh; community dock/parking ratings |
| [PTV Navigator](https://www.ptvlogistics.com/en-us/products/ptv-navigator/features) | Fleet app + API | Full truck attrs + ADR; remote profile sync; telematics |
| [Trimble CoPilot](https://transportation.trimble.com/en/solutions/mapping-and-routing/copilot) | Fleet nav | PC\*Miler; planned=driven=billed; HOS; fleet portal |
| [HERE Pro Nav](https://www.here.com/solutions/professional-navigation) | Platform | Commercial routing; multi-stop fleet optimization |
| [Samsara](https://www.samsara.com/uk/products/telematics/tachograph) / [Geotab](https://www.geotab.com/uk/fleet-management-solutions/smart-digital-tachograph/) | Telematics | UK/EU tacho — not consumer truck GPS |

## Capability matrix (RouteFinder after Phases 0–5)

| Capability | RouteFinder | Typical truck GPS | Fleet telematics | Notes |
|---|---|---|---|---|
| Full constraint routing on live route | **Strong** (ORS L/W/H/length/axle/hazmat/ADR/avoids) | Strong | Strong | Phase 0–2 |
| Offline maps | **UK region packs** (H3 routing tiles + local map-pack HTTP) | Strong | Hybrid | Phase 3–4 |
| Truck POI network | **Fuel / parking / weigh / layby along-route** (+ disk cache + occupancy prior) | Strong | Weak as nav | Living layer |
| Physics pre-trip + kinetic risk | **Strong** (Rehearse + live HUD/voice + shareable brief) | Absent | Absent | Wedge |
| Plate → auto vehicle profile (UK) | **Strong** (RegCheck + DVLA chain) | Manual | Asset registry | UK first |
| CarPlay production quality | **Hardened TBT + Always GPS path + voice ducking + HOS advisory alert** | Strong (Sygic) | Varies | Shipped |
| Multi-stop optimize | Shipped | Shipped | Strong | Existing |
| Live traffic affecting route choice | **TomTom flow → ORS avoid_polygons reroute** | Strong | Strong | Phase 2 |
| HOS / tacho | **Advisory EU 561 + JSON/DDD import + Can-I-drive** (VU remains legal) | Weak | **Strong** | Phase 1 + 5; partner port stubbed |
| Fleet dispatch / shared physics ETA | **MVP** (disk-backed org→trip→snapshot) | Weak | **Strong** | Phase 2 |
| Driver community dock/parking intel | Hazard / crowd confidence on POIs | Garmin community | Crowdsource | Partial |
| Walkaround inspection | **Local DVSA checklist + disk store** | Varies | Strong | Glass UI |

## White space RouteFinder owns

1. Pre-trip physics rehearsal of the constrained route (“Rehearse Route”)
2. Live kinetic advisories (brake fade / grade / slip) fused with voice
3. Shareable predictive trip brief / risk index
4. UK plate → dims + DVLA registry chain
5. Physics ETA published back to dispatch on fleet trips
6. Honest advisory tacho (import + clock) that never claims to replace the VU

## 90-day bar checklist

- [x] Routes legally respect full vehicle profile on ORS
- [x] Pre-trip physics rehearsal + live kinetic voice
- [x] CarPlay continuous TBT with voice coexistence hooks
- [x] Truck fuel/parking/weigh along-route (20 mi) + UK LEZ banners
- [x] Single-fleet MVP push trip + physics ETA snapshot
- [x] Advisory HOS clock + rest forecast + DDD/JSON import
- [x] Offline routing tiles + local map-pack path (Phase 3–4)
- [x] Traffic-aware reroute + driving bans + walkaround inspection
- [ ] Parallel deep-research refresh (blocked: API unreachable)
- [ ] Full Samsara-class remote VU (partner, don’t rebuild)

## Quarterly parity checklist vs Sygic / TomTom / PTV / CoPilot

| Quarter item | Owner | Status |
|---|---|---|
| Dimensional + hazmat/ADR routing parity | ConstraintParity | Done |
| Physics wedge differentiation | PhysicsWedge | Done |
| CarPlay TBT + background GPS | CarPlayNav | Done |
| UK truck living layer | UKLivingLayer | Done |
| Fleet dispatch MVP | FleetBackend | Done (in-memory) |
| Advisory tacho + Can-I-drive | AdvisoryTacho | Done (Phase 5) |
| Offline map packs | OfflineMaps | Pending |
| Competitive intel refresh | CompetitiveIntel | Pending Parallel API |

## Sources

- [Sygic Truck](https://www.sygic.com/truck)
- [Sygic Truck features guide](https://help.sygic.com/hc/en-us/articles/37948287320338-Features-and-user-guide-for-Sygic-Truck-Caravan-Navigation)
- [Sygic CarPlay/Android Auto](https://www.sygic.com/what-is/sygic-gps-truck-caravan-androidauto-carplay-us)
- [TomTom GO Professional](https://www.tomtom.com/en_gb/navigation/truck-gps-sat-nav/go-professional/)
- [TomTom GO Professional EU manual](https://download.tomtom.com/open/manuals/GO_Professional/refman/TomTom-GO_PROFESSIONAL-EU-UM-en-gb.pdf)
- [Garmin dēzl OTR press](https://www.garmin.com/en-US/newsroom/press-release/automotive/garmin-introduces-refreshed-dezl-otr-navigator-series-with-insights-from-fellow-truck-drivers/)
- [PTV Navigator features](https://www.ptvlogistics.com/en-us/products/ptv-navigator/features)
- [Trimble CoPilot](https://transportation.trimble.com/en/solutions/mapping-and-routing/copilot)
- [HERE Professional Navigation](https://www.here.com/solutions/professional-navigation)
- [State of Truck Navigation 2025](https://local-eyes.nl/the-state-of-truck-navigation-in-2025-what-fleets-need-who-delivers/)
- [Samsara tachograph](https://www.samsara.com/uk/products/telematics/tachograph)
- [Geotab digital tachograph](https://www.geotab.com/uk/fleet-management-solutions/smart-digital-tachograph/)
