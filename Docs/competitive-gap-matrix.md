# HGV Navigation Competitive Gap Matrix

Last updated: 2026-08-27 (driver layby occupancy report)  
Strategy: global vision, **ship UK first**; differentiate on physics-sim + predictive telematics, then CarPlay parity, then fleet/dispatch, then advisory tacho + offline packs.

> Parallel API refresh was attempted via `parallel-cli` but the API was unreachable from this environment (`APIConnectionError`). This matrix is maintained from the competitive plan’s live web sources plus a post-implementation codebase inventory. Re-run Parallel when `api.parallel.ai` is reachable.

## Programme status (Phases 0–19)

| Phase | Focus | Status |
|---|---|---|
| **0** | Living-layer domain types (vector, crowd, layby, HOS/inspection/dock/alert) | **Done** |
| **1** | EU 561 advisory HOS clock + rest insertion + HUD | **Done** |
| **2** | Constraint parity, physics wedge, traffic/POI/fleet/inspection hardening | **Done** (inspections: local disk + glass checklist) |
| **3** | Offline H3 tile pipeline / graph store path | **Done** — `DiskOfflineGraphStore` + hybrid ORS/offline policy + tile scripts |
| **4** | Offline map packs in MapLibre WKWebView | **Done** — local HTTP pack server + bundled MapLibre preference |
| **5** | Advisory tacho — DDD/JSON import, Can-I-drive, partner stub | **Done** |
| **6** | Product hygiene — README, this matrix, glass surfaces | **Done** |
| **7** | Layby prediction v2 — fused HOS + company breaks + physics + occupancy | **Done** — `LaybyPredictionEngine` + `CompanyBreakAllocation` on `FleetTrip` |
| **8** | Native dispatch console — macOS window + iPad split + driver poll loop | **Done** — geocoded stops, ORS preview, push toast, iPad driver default |
| **9** | Shareable predictive trip brief — unified telemetry + HOS + layby + fleet | **Done** — `TripBriefContext` + ShareLink on driver and dispatch |
| **10** | Multi-device fleet sync — Hummingbird LAN server + HTTPFleetStore | **Done** — `RouteFinderFleetServer` + Settings remote URL; hot-reload in Phase 12 |
| **11** | Shareable trip brief PDF export — office-ready PDF from same context | **Done** — `TripBriefPDFRenderer` + share menu (text); route map in Phase 15 |
| **12** | Fleet store hot-reload — switch disk/HTTP without app restart | **Done** — `fleetStoreConfigurationDidChange` + VM reload |
| **13** | Fleet LAN auth + TLS — shared-secret API key + optional HTTPS | **Done** — `FleetAuthMiddleware` + Keychain client key |
| **14** | Bonjour fleet server discovery — advertise + Settings LAN picker | **Done** — `_routefinder-fleet._tcp` + Discover in Settings |
| **15** | PDF trip brief route map snapshot — MapKit overview in PDF export | **Done** — `RouteMapSnapshotRenderer` + async PDF share |
| **16** | Fleet dispatch SSE push — instant driver notification on trip push | **Done** — `FleetEventHub` + `FleetSSEClient` + driver toast |
| **17** | OpenWeather weather fallback — live auto road conditions without WeatherKit | **Done** — `DefaultWeatherService` prefers OpenWeather when key present |
| **18** | Weather backend hot-reload — OpenWeather key save switches live weather without restart | **Done** — `weatherConfigurationDidChange` + `WeatherViewModel.replaceWeatherService` |
| **19** | Driver layby occupancy report — Looks full / Has spaces feeds on-device crowd prior | **Done** — `LaybyOccupancyReport` + disk `LocalCrowdEventIngest` |

### Remaining gaps (explicitly not claiming parity)

- Full multi-country **toll tariff tables**
- **Remote VU download** (partner SDK — VDO / Stoneridge / Samsara)
- **Android Auto**
- **In-process planet PBF** parser (pipeline uses osmium + `PBFPreprocessor` / tile scripts instead)
- Paid live fuel-price API / SNAP booking
- **Hosted fleet web portal / multi-tenant SaaS** (native dispatch + secured LAN server shipped; hosted portal deferred)

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
| Fleet dispatch / shared physics ETA | **Shipped** (native dispatch + LAN sync + trip brief ShareLink) | Weak | **Strong** | Phase 8–10 |
| Predictive layby / break stop | **Strong** (fused HOS + company window + physics + occupancy; $0 APIs) | Weak (CoPilot: HOS breaks + paid parking hold) | Weak | **Wedge vs CoPilot** — no parking booking fee |
| Driver community dock/parking intel | **On-device layby Full/Spaces reports** → occupancy prior + POI confidence | Garmin community | Crowdsource | Phase 19 |
| Walkaround inspection | **Local DVSA checklist + disk store** | Varies | Strong | Glass UI |

## White space RouteFinder owns

1. Pre-trip physics rehearsal of the constrained route (“Rehearse Route”)
2. Live kinetic advisories (brake fade / grade / slip) fused with voice
3. Shareable predictive trip brief / risk index — **shipped** (unified plain-text brief + ShareLink)
4. UK plate → dims + DVLA registry chain
5. Physics ETA published back to dispatch on fleet trips
6. Honest advisory tacho (import + clock) that never claims to replace the VU
7. **Predictive layby ranker** — last feasible stop before advisory HOS / company break window, with physics upstream bias (CoPilot has HOS breaks; we add UK OSM laybys + physics at $0/hosting)

### vs Trimble CoPilot (Aug 2026)

| | CoPilot | RouteFinder |
|---|---|---|
| HOS break planning | ELD sync + rest stops on route | Advisory EU 561 + company `CompanyBreakAllocation` |
| Predictive parking | Truck Parking Club booking (paid) | OSM layby + hour-of-day occupancy prior (free) |
| Fleet portal | FleetPortal / Account Manager (per-seat SaaS) | Native macOS window + iPad split dispatch at **$0** (`DiskFleetStore`) |
| Physics rehearsal | Absent | Pre-trip kinetic sim + physics ETA |
| Cost at 1k drivers | Quote-only fleet seats | ORS free tier + optional TomTom; ranker is on-device |

**Do not chase:** CoPilot parking booking, ELD vendor lock-in, Android-first CoPilot 11 parity yet.


## 90-day bar checklist

- [x] Routes legally respect full vehicle profile on ORS
- [x] Pre-trip physics rehearsal + live kinetic voice
- [x] CarPlay continuous TBT with voice coexistence hooks
- [x] Truck fuel/parking/weigh along-route (20 mi) + UK LEZ banners
- [x] Single-fleet MVP push trip + physics ETA snapshot
- [x] Advisory HOS clock + rest forecast + DDD/JSON import
- [x] Offline routing tiles + local map-pack path (Phase 3–4)
- [x] Fused layby prediction v2 (HOS + company breaks + physics + occupancy)
- [x] Shareable predictive trip brief (driver + dispatch ShareLink)
- [x] Shareable trip brief PDF export (driver + dispatch)
- [ ] Parallel deep-research refresh (blocked: API unreachable)
- [ ] Full Samsara-class remote VU (partner, don’t rebuild)

## Quarterly parity checklist vs Sygic / TomTom / PTV / CoPilot

| Quarter item | Owner | Status |
|---|---|---|
| Dimensional + hazmat/ADR routing parity | ConstraintParity | Done |
| Physics wedge differentiation | PhysicsWedge | Done |
| CarPlay TBT + background GPS | CarPlayNav | Done |
| UK truck living layer | UKLivingLayer | Done |
| Fleet dispatch MVP | FleetBackend | Done (`DiskFleetStore`) |
| Predictive layby v2 | LaybyIntel | Done |
| Advisory tacho + Can-I-drive | AdvisoryTacho | Done (Phase 5) |
| Offline map packs | OfflineMaps | Done (Phase 4) |
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
