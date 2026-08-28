# HGV Navigation Competitive Gap Matrix

Last updated: 2026-08-28 (post-Phase 23 hotfixes verified)  
Strategy: global vision, **ship UK first**; differentiate on physics-sim + predictive telematics, then CarPlay parity, then fleet/dispatch, then advisory tacho + offline packs.

> **Aug 28 hotfixes (verified):** data-protection Keychain persistence (`RouteFinderMac` + hardened packaged app), global Pelias geocode (`33 sørnesvegen` Ålesund), LEZ avoid long-haul cap (ORS 2004), simulation cruise feel (softened curve governor), camera follow on vehicle geometric center (zoom 15). Package script hardened for macOS 26 (`--options runtime`). See [`phase20-verification.md`](phase20-verification.md#post-fix-verification-2026-08-28).

> Phase 20 refreshed competitor intel from public product pages (2026-08-27). Parallel deep-research remains blocked (`APIConnectionError` / `api.parallel.ai` unreachable). Firecrawl CLI was unavailable in-session; sources below are live web pages.

## Programme status (Phases 0–23)

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
| **20** | Competitive refresh + product verification | **Done** — see [`phase20-verification.md`](phase20-verification.md) |
| **21** | UK LEZ / CAZ avoid-on-route — EmissionClass + ORS `avoid_polygons` | **Done** — `LEZAvoidPolicy` + Settings toggle; destination-inside zones still allowed |
| **22** | Layby community signal expansion — age-weighted multi-report prior + last-seen banner | **Done** — `ParkingOccupancyPrior` fusion + `LaybyAdvisory` last-seen fields |
| **23** | UK LEZ / CAZ geometry upgrade — hand-authored simplified boundary rings | **Done** — `UKLowEmissionZoneBoundaries` (approximate envelopes, not legal cadastral) |

### Remaining gaps (explicitly not claiming parity)

- Full multi-country **toll tariff tables**
- **Remote VU download** (partner SDK — VDO / Stoneridge / Samsara)
- **Android Auto**
- **In-process planet PBF** parser (pipeline uses osmium + `PBFPreprocessor` / tile scripts instead)
- Paid live fuel-price API / SNAP booking
- **Hosted fleet web portal / multi-tenant SaaS** (native dispatch + secured LAN server shipped; hosted portal deferred)
- Legal cadastral LEZ polygons / diesel vs petrol nuance (authored rings are simplified envelopes)

## Competitor strengths (Phase 20 refresh — 2026-08-27)

| Competitor | Form | Notable strengths (2026 public pages) | Delta vs prior matrix |
|---|---|---|---|
| [Sygic Truck](https://www.sygic.com/truck) | Phone app | Offline truck maps; dims/hazmat; [LEZ alerts + emit-profile reroute](https://www.sygic.com/what-is/low-emission-zones); fuel prices; [CarPlay/AA as premium add-on](https://help.sygic.com/hc/en-us/articles/38176591980434-Android-Auto-Apple-CarPlay-in-Sygic-Truck-Caravan-Navigation); Route Sender | LEZ avoid depth + paid CarPlay add-on clarified |
| [TomTom GO Professional](https://www.tomtom.com/en_gb/navigation/truck-gps-sat-nav/go-professional/) | Hardware | L/W/H, axle, hazmat, ADR tunnels, truck POIs, TomTom Traffic; LEZ map + avoid on NDS devices ([manual](https://download.tomtom.com/open/manuals/TomTom_GO_Prof2ndGen/refman/TomTom-GO-PROFESSIONAL-2nd-Gen-EU-UM-en-gb.pdf)) | Unchanged core; LEZ avoid still a hardware strength |
| [Garmin dēzl OTR](https://www.garmin.com/en-US/newsroom/press-release/automotive/garmin-introduces-refreshed-dezl-otr-navigator-series-with-insights-from-fellow-truck-drivers/) | Hardware | Truckstops/parking/weigh; community dock/parking ratings; satellite arrival imagery | Community parking still the wedge they own on hardware |
| [PTV Navigator](https://www.ptvlogistics.com/en-us/products/ptv-navigator/features) | Fleet app + API | Full truck attrs + ADR; remote profile sync; telematics | Unchanged — enterprise remote profiles |
| [Trimble CoPilot](https://transportation.trimble.com/en/solutions/mapping-and-routing/copilot) | Fleet nav | PC\*Miler; [CoPilot 11](https://developer.trimblemaps.com/copilot-navigation/release-notes/introduction-copilot-11/): predictive parking + HOS clocks (US/CA + ELD); Book Parking (TPC/BTP US; select EU); Android Auto; Account Manager (ex-FleetPortal) | Book Parking → EU select sites; HOS still US-shaped ELD |
| [HERE Pro Nav](https://www.here.com/solutions/professional-navigation) | Platform | Commercial routing; multi-stop fleet optimization | Unchanged |
| [Samsara](https://www.samsara.com/uk/products/telematics/tachograph) / [Geotab](https://www.geotab.com/uk/fleet-management-solutions/smart-digital-tachograph/) | Telematics | UK/EU remote VU / driver-card download | Still partner territory — do not rebuild |

## Capability matrix (RouteFinder after Phases 0–20)

| Capability | RouteFinder | Typical truck GPS | Fleet telematics | Notes |
|---|---|---|---|---|
| Full constraint routing on live route | **Strong** (ORS L/W/H/length/axle/hazmat/ADR/avoids) | Strong | Strong | Phase 0–2 |
| Offline maps | **UK region packs** (H3 routing tiles + local map-pack HTTP) | Strong | Hybrid | Phase 3–4 |
| Truck POI network | **Fuel / parking / weigh / layby along-route** (+ disk cache + occupancy prior) | Strong | Weak as nav | Living layer |
| Physics pre-trip + kinetic risk | **Strong** (Rehearse + live HUD/voice + shareable brief) | Absent | Absent | Wedge |
| Plate → auto vehicle profile (UK) | **Strong** (RegCheck + DVLA chain) | Manual | Asset registry | UK first |
| CarPlay production quality | **Hardened in code**; personal-team builds **inactive** | Strong (Sygic) | Varies | Paid team / entitlements for device QA |
| Multi-stop optimize | Shipped | Shipped | Strong | Existing |
| Live traffic affecting route choice | **TomTom flow → ORS avoid_polygons reroute** | Strong | Strong | Phase 2 |
| HOS / tacho | **Advisory EU 561 + JSON/DDD import + Can-I-drive** (VU remains legal) | Weak | **Strong** | Phase 1 + 5; partner port stubbed |
| Fleet dispatch / shared physics ETA | **Shipped** (native dispatch + LAN sync + SSE + trip brief) | Weak | **Strong** | Phase 8–16 |
| Predictive layby / break stop | **Strong** (fused HOS + company window + physics + occupancy; $0 APIs) | Weak (CoPilot: HOS breaks + paid parking hold) | Weak | **Wedge vs CoPilot** — no parking booking fee |
| Driver community dock/parking intel | **Age-weighted multi-report Full/Spaces** + last-seen banner copy | Garmin community | Crowdsource | Phase 19–22 |
| LEZ compliance | **Banners + avoid-on-route** with **simplified authored rings** (Euro 6 exempt; destination-inside allowed) | Strong avoid (Sygic/TomTom) | Varies | Phase 21–23 |
| Walkaround inspection | **Local DVSA checklist + disk store** | Varies | Strong | Glass UI |
| Live weather road conditions | **OpenWeather preferred** + WeatherKit fallback | Varies | Strong | Phase 17–18; WeatherKit needs paid team |

## White space RouteFinder owns

1. Pre-trip physics rehearsal of the constrained route (“Rehearse Route”)
2. Live kinetic advisories (brake fade / grade / slip) fused with voice
3. Shareable predictive trip brief / risk index — **shipped** (unified plain-text brief + ShareLink + PDF)
4. UK plate → dims + DVLA registry chain
5. Physics ETA published back to dispatch on fleet trips
6. Honest advisory tacho (import + clock) that never claims to replace the VU
7. **Predictive layby ranker** — last feasible stop before advisory HOS / company break window, with physics upstream bias (CoPilot has HOS breaks; we add UK OSM laybys + physics at $0/hosting)
8. **$0 fleet LAN** — Bonjour + optional API key/TLS vs CoPilot Account Manager seats

### vs Trimble CoPilot (Aug 2026 refresh)

| | CoPilot 11.x | RouteFinder |
|---|---|---|
| HOS break planning | ELD sync + rest stops (US/CA; Trip Management license) | Advisory EU 561 + company `CompanyBreakAllocation` |
| Predictive parking | Live insights + driver Plenty/Limited/None feedback (US/CA); Book Parking TPC/BTP (+ select EU) | OSM layby + hour-of-day prior + **Looks full / Has spaces** (free, UK-first) |
| Fleet portal | Account Manager (per-seat SaaS) | Native macOS/iPad dispatch + LAN HTTP at **$0** |
| Physics rehearsal | Absent | Pre-trip kinetic sim + physics ETA |
| Android Auto | Shipped in CoPilot 11 | Deferred |
| Cost at 1k drivers | Quote-only fleet seats | ORS free tier + optional TomTom/OpenWeather; ranker on-device |

**Do not chase:** CoPilot parking booking fees, ELD vendor lock-in, Android Auto, hosted multi-tenant SaaS — unless an urgent UK wedge appears.

## Phase 24+ backlog (ranked)

1. **Phase 24:** Paid-team CarPlay entitlement restore + device QA checklist (only when signing allows).
2. **Defer:** toll tariff tables, remote VU download, Android Auto, hosted fleet SaaS, paid SNAP/fuel APIs, legal cadastral LEZ polygons.

## 90-day bar checklist

- [x] Routes legally respect full vehicle profile on ORS
- [x] Pre-trip physics rehearsal + live kinetic voice
- [x] CarPlay continuous TBT with voice coexistence hooks *(code; personal-team inactive)*
- [x] Truck fuel/parking/weigh along-route (20 mi) + UK LEZ banners
- [x] Single-fleet MVP push trip + physics ETA snapshot
- [x] Advisory HOS clock + rest forecast + DDD/JSON import
- [x] Offline routing tiles + local map-pack path (Phase 3–4)
- [x] Fused layby prediction v2 (HOS + company breaks + physics + occupancy)
- [x] Shareable predictive trip brief (driver + dispatch ShareLink)
- [x] Shareable trip brief PDF export (driver + dispatch)
- [x] Competitive intel refresh (Phase 20 public-web; Parallel still blocked)
- [ ] Full Samsara-class remote VU (partner, don’t rebuild)
- [x] LEZ avoid-on-route (Phase 21)

## Quarterly parity checklist vs Sygic / TomTom / PTV / CoPilot

| Quarter item | Owner | Status |
|---|---|---|
| Dimensional + hazmat/ADR routing parity | ConstraintParity | Done |
| Physics wedge differentiation | PhysicsWedge | Done |
| CarPlay TBT + background GPS | CarPlayNav | Done *(code; personal-team signing inactive)* |
| UK truck living layer | UKLivingLayer | Done |
| Fleet dispatch MVP | FleetBackend | Done (`DiskFleetStore` + LAN) |
| Predictive layby v2 | LaybyIntel | Done |
| Advisory tacho + Can-I-drive | AdvisoryTacho | Done (Phase 5) |
| Offline map packs | OfflineMaps | Done (Phase 4) |
| Competitive intel refresh | CompetitiveIntel | **Partial** — Phase 20 public-web Done; Parallel API still Pending |
| LEZ avoid-on-route | UKLivingLayer | **Done** (Phase 21) |
| LEZ simplified geometry | UKLivingLayer | **Done** (Phase 23) |

## Sources

- [Sygic Truck](https://www.sygic.com/truck)
- [Sygic Truck features guide](https://help.sygic.com/hc/en-us/articles/37948287320338-Features-and-user-guide-for-Sygic-Truck-Caravan-Navigation) *(updated ~2026-08)*
- [Sygic LEZ](https://www.sygic.com/what-is/low-emission-zones)
- [Sygic CarPlay/Android Auto](https://help.sygic.com/hc/en-us/articles/38176591980434-Android-Auto-Apple-CarPlay-in-Sygic-Truck-Caravan-Navigation) *(updated 2026-08-18)*
- [TomTom GO Professional](https://www.tomtom.com/en_gb/navigation/truck-gps-sat-nav/go-professional/)
- [TomTom GO Professional 2nd Gen EU manual](https://download.tomtom.com/open/manuals/TomTom_GO_Prof2ndGen/refman/TomTom-GO-PROFESSIONAL-2nd-Gen-EU-UM-en-gb.pdf)
- [Garmin dēzl OTR press](https://www.garmin.com/en-US/newsroom/press-release/automotive/garmin-introduces-refreshed-dezl-otr-navigator-series-with-insights-from-fellow-truck-drivers/)
- [PTV Navigator features](https://www.ptvlogistics.com/en-us/products/ptv-navigator/features)
- [Trimble CoPilot product](https://transportation.trimble.com/en/solutions/mapping-and-routing/copilot)
- [CoPilot 11 introduction](https://developer.trimblemaps.com/copilot-navigation/release-notes/introduction-copilot-11/)
- [CoPilot 11.0 / Book Parking notes](https://developer.trimblemaps.com/copilot-navigation/release-notes/v11_0/)
- [CoPilot upgrade notes (incl. Jan 2026 11.3)](https://developer.trimblemaps.com/copilot-navigation/release-notes/upgrade-copilot/)
- [HERE Professional Navigation](https://www.here.com/solutions/professional-navigation)
- [Samsara tachograph](https://www.samsara.com/uk/products/telematics/tachograph)
- [Geotab digital tachograph](https://www.geotab.com/uk/fleet-management-solutions/smart-digital-tachograph/)
- Verification: [`Docs/phase20-verification.md`](phase20-verification.md)
