# HGV Navigation Competitive Gap Matrix

Last updated: 2026-08-29 (Phase 45–48 reliability economics program)  
Strategy: global vision, **ship UK first**; differentiate on physics-sim + predictive telematics, then fleet/dispatch, then advisory tacho + offline packs. **CarPlay deferred** until paid-team signing.

> **Aug 29 Phase 45–48:** On-device API usage ledger + soft budget guards; unified remote retry policy; `FleetDispatchCoordinator` + `HazardNavigationCoordinator` extracted from `RouteViewModel`; fleet E2E smoke in CI; architecture ADR. See [`unit-economics.md`](unit-economics.md), [`architecture.md`](architecture.md), and [`phase20-verification.md`](phase20-verification.md#phase-4548-reliability-economics-program-2026-08-29).

> **Aug 29 Phase 43–44:** GitHub Actions moved to repo-root `.github/workflows/ci.yml` with correct package working directory; dispatch toast when walkaround defects arrive via poll. See [`phase20-verification.md`](phase20-verification.md#phase-4344-ci-fix--dispatch-defect-toast-2026-08-29).

> **Aug 29 Phase 41–42:** Dispatch console walkaround defect card + PDF share; fleet LAN inspection snapshot E2E; CI `RouteFinderAppUITests`. See [`phase20-verification.md`](phase20-verification.md#phase-4142-dispatch-inspection--ci-2026-08-29).

> **Aug 28 Phase 38–40:** iOS XCTest smoke (cold launch, settings hub, walkaround entry); walkaround defect warning in shareable trip brief + optional fleet inspection PDF on LAN snapshot; hazard map overlay rebuild on crowd hydrate. See [`phase20-verification.md`](phase20-verification.md#phase-3840-automation--fleet-handoff-2026-08-28).

> **Aug 28 Phase 36:** TomTom live traffic/closure ahead sampling during GPS nav; crowd hazard hydration on route load; roadworks disk cache. See [`phase20-verification.md`](phase20-verification.md#phase-36-hazard-hardening-2026-08-28).

> **Aug 28 Phase 33–35:** Live closure/traffic hazard ahead alerts; Settings hub sub-menus; OSM roadworks-ahead banner. See [`phase20-verification.md`](phase20-verification.md#phase-3335-driver-alerts--settings-2026-08-28).

> **Aug 28 Phase 30–32:** Layby proactive voice + skip-to-next toast; zoned DVSA walkaround v2 with PDF share; fuel card provider advisory on ahead-of-route truck POIs. See [`phase20-verification.md`](phase20-verification.md#phase-3032-driver-facing-wins-2026-08-28).

> **Aug 28 Phase A (iOS):** MapBootstrapServer loopback HTTP fixes sandbox map error; iOS login gate; walkaround onboarding + toolbar; liability acceptance. Device QA checklist in [`phase20-verification.md`](phase20-verification.md#phase-a-ios-device-qa-2026-08-28).

> **Aug 28 Phase 26:** Market research pack (4 docs + `.firecrawl/` summaries). Shipped Break Now quick action, LEZ catalog expansion (11 zones) + Euro-class copy, lane voice at prepare/execute tiers. See [`competitive-research-2026-08.md`](competitive-research-2026-08.md) and [`phase20-verification.md`](phase20-verification.md#phase-26-live-qa).

> **Aug 28 Sim UX:** session/workspace persistence, traffic cruise toggle (default off), center-anchored cab/trailer model, OSM `turn:lanes` lane banner with heuristic fallback + async Overpass enrichment (capped). See [`phase20-verification.md`](phase20-verification.md#sim-ux--lane-guidance-2026-08-28).

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
| **24** | Sim UX persistence + lane guidance hardening | **Done** — Touch ID session, workspace snapshot, traffic cruise toggle, cab/trailer model, map-top lane banner, capped async Overpass enrichment |
| **25** | Market research + gap ranking (Aug 2026) | **Done** — 4 research docs, scorecard, pricing, personas; CoPilot TRAVIS / Break Now deltas captured |
| **26** | Break Now + LEZ v2 + lane voice polish | **Done** — HUD Break Now, 11 UK LEZ zones, Euro-class banners, `spokenLanePhrase` voice |
| **30** | Layby proactive alerts — voice + skip-to-next toast + GPS throttle | **Done** — `LaybyAlertFormatter`, Settings toggle, throttled GPS refresh |
| **31** | Comprehensive walkaround v2 — zoned DVSA checklist + defect notes + PDF | **Done** — 7 zones, completion gate, `InspectionReportPDFRenderer` |
| **32** | Fuel card provider advisory — brand match on ahead POIs | **Done** — Settings picker, `FuelCardMatcher`, ahead banner |
| **33** | Live closure/traffic hazard ahead alerts during navigation | **Done** — `HazardAheadFormatter`, voice + banner, crowd + promoted hazards |
| **34** | Settings hub sub-menus | **Done** — drill-down NavigationLink groups |
| **35** | Roadworks ahead on route (OSM) | **Done** — `RoadworksAlongRouteRepository`, corridor banner |
| **36** | TomTom live hazard ahead + crowd hydrate + roadworks cache | **Done** — `LiveTrafficHazardSampler`, `promotedHazards`, `RoadworksDiskCache` |
| **38** | iOS XCTest smoke + accessibility IDs + auth bypass launch args | **Done** — `RouteFinderAppUITests` |
| **39** | Walkaround defect line in trip brief + fleet inspection PDF snapshot | **Done** — `TripBriefInspectionSummary`, `publishInspectionFleetHandoff` |
| **40** | Hazard map overlay rebuild on crowd hydrate | **Done** — `HazardOverlayBuilder` |
| **41** | Dispatch console inspection defect card + PDF share | **Done** — `DispatchStatusPanel` |
| **42** | Fleet E2E inspection snapshot + CI UI smoke | **Done** — `FleetSSETests`, `.github/workflows/ci.yml` |
| **43** | GitHub Actions repo-root CI fix | **Done** — root `.github/workflows/ci.yml`, `RouteFinder/` working directory |
| **44** | Dispatch toast on walkaround defects via poll | **Done** — `DispatchInspectionAnnouncer`, `DispatchViewModel` |
| **45** | API usage ledger + soft budget guards | **Done** — `APIUsageLedger`, Settings usage panel, [`unit-economics.md`](unit-economics.md) |
| **46** | Unified remote request policy + fleet CI smoke | **Done** — `RemoteRequestPolicy`, `fleet-e2e-smoke.sh` in CI |
| **47** | Fleet + hazard coordinator extraction | **Done** — `FleetDispatchCoordinator`, `HazardNavigationCoordinator`, [`architecture.md`](architecture.md) |
| **48** | Reliability SLO verification gate | **Done** — [`phase20-verification.md`](phase20-verification.md#phase-4548-reliability-economics-program-2026-08-29); C1–C9 unblocked |
| **49a** | Fix MapKit/CLGeocoder Sendable macOS CI failure | **Done** — CI green on `8f4ff6ee` ([run 33253641183](https://github.com/thesnjk/RouteFinder/actions/runs/33253641183)) |
| **49b** | iPhone C1–C9 + fleet Part B device gate | **Pending local** — checklist ready; see [`phase20-verification.md`](phase20-verification.md#phase-49b--device-validation-gate-2026-08-29) |
| **49c** | Fleet SSE CI flake hardening | **Done** — `waitForFleetServerReady` health poll |
| **50** | Route planning coordinator extraction | **Done** — `RoutePlanningCoordinator`, `RoutePlanningHost`, tests |
| **51** | Route simulation coordinator extraction | **Done** — `RouteSimulationCoordinator`, `RouteSimulationHost`, tests |
| **52** | HOS advisory coordinator extraction | **Done** — `HosAdvisoryCoordinator`, `HosAdvisoryHost`, tests |
| **53** | Pilot GTM prep (Driver Terms + pilot pack) | **Done** — docs + liability hardening; device/pilot meetings **Pending local** |

### Remaining gaps (explicitly not claiming parity)

- **CarPlay / Android Auto** (deferred — personal-team entitlements)

- Full multi-country **toll tariff tables**
- **Remote VU download** (partner SDK — VDO / Stoneridge / Samsara)
- **Android Auto**
- **In-process planet PBF** parser (pipeline uses osmium + `PBFPreprocessor` / tile scripts instead)
- Paid live fuel-price API / SNAP booking / **TRAVIS parking booking** (CoPilot Jul 2026)
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
| Fleet dispatch / shared physics ETA | **Shipped** (native dispatch + LAN sync + SSE + trip brief + inspection PDF + defect card + poll toast) | Weak | **Strong** | Phase 8–16 + Ph39–44 |
| Predictive layby / break stop | **Strong** (fused HOS + company window + physics + occupancy + **Break Now**; $0 APIs) | Weak (CoPilot: HOS breaks + TRAVIS booking) | Weak | **Wedge vs CoPilot** — no parking booking fee |
| Driver community dock/parking intel | **Age-weighted multi-report Full/Spaces** + last-seen banner copy | Garmin community | Crowdsource | Phase 19–22 |
| LEZ compliance | **Banners + avoid-on-route** with **11 zones** (6 authored rings + 5 circle envelopes); Euro-class copy | Strong avoid (Sygic/TomTom) | Varies | Phase 21–23, **26** |
| Lane-level junction guidance | **OSM `turn:lanes` + heuristic**; map-top banner; **prepare/execute lane voice** | Strong (TomTom/Sygic) | Weak | Phase 24, **26** |
| Walkaround inspection | **Zoned DVSA checklist (7 zones) + defect notes + PDF share + trip brief warning** | Varies | Strong | Phase 31 + Ph39 fleet handoff |
| Live weather road conditions | **OpenWeather preferred** + WeatherKit fallback | Varies | Strong | Phase 17–18; WeatherKit needs paid team |
| Layby proactive driver notify | **Voice announce + skip-to-next toast** (Settings toggle) | Weak (CoPilot HOS breaks) | Weak | Phase 30 |
| Fleet fuel card POI advisory | **OSM brand/name match banner** (Keyfuels, UK Fuels, AllStar, Esso, BP) | Fuel prices (Sygic) | Weak | Phase 32; no paid fuel API |
| Live closure / hazard ahead alert | **Voice + banner** (crowd + TomTom live + promoted hazards) | Waze-style crowd | Weak | Phase 33 + 36 |
| Roadworks ahead advisory | **OSM construction along corridor** | Varies | Weak | Phase 35; $0 Overpass |

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
| HOS break planning | ELD sync + rest stops (US/CA; Trip Management license) | Advisory EU 561 + company `CompanyBreakAllocation` + **Break Now** |
| Predictive parking | TRAVIS 750+ EU booking (Jul 2026) + US/CA live feedback | OSM layby + occupancy taps + **Break Now** (no booking fee) |
| Fleet portal | Account Manager (per-seat SaaS) | Native macOS/iPad dispatch + LAN HTTP at **$0** |
| Physics rehearsal | Absent | Pre-trip kinetic sim + physics ETA |
| Android Auto | Shipped in CoPilot 11 | Deferred |
| Cost at 1k drivers | Quote-only fleet seats | ORS free tier + optional TomTom/OpenWeather; ranker on-device |

**Do not chase:** CoPilot parking booking fees, ELD vendor lock-in, Android Auto, hosted multi-tenant SaaS — unless an urgent UK wedge appears.

## Phase 27+ backlog (ranked)

1. **Driver onboarding sheet** — **Done** (Phase 27a) — in-app "What RouteFinder does" linking [`user-guide-simulation.md`](user-guide-simulation.md).
2. **Map label i18n** — **Done** (Phase 27b) — MapLibre label language preference in Settings.
3. **Fleet E2E scripted QA** — **Done** (Phase 27c) — [`fleet-e2e-qa.md`](fleet-e2e-qa.md) + `Scripts/fleet-e2e-smoke.sh`.
4. **Paid-team CarPlay entitlement restore** — playbook only; see [`carplay-weatherkit-restore.md`](carplay-weatherkit-restore.md). Execute when signing allows (explicitly deferred from Phase 26 on personal team).
5. **Defer:** toll tariff tables, remote VU download, Android Auto, hosted fleet SaaS, paid SNAP/fuel APIs, legal cadastral LEZ polygons, TRAVIS booking integration.

## Phase 28+ backlog (ranked)

1. **CarPlay + WeatherKit entitlement restore** — **Blocked — paid team** — follow [`carplay-weatherkit-restore.md`](carplay-weatherkit-restore.md) when on a paid Apple Developer Program team with CarPlay Maps + WeatherKit capabilities.
2. **Quarterly competitive refresh** — **Done (Ph29 light)** — positioning narrative updated in [`competitive-research-2026-08.md`](competitive-research-2026-08.md) and scorecard; no full re-scrape.
3. **Defer:** toll tariff tables, remote VU download, Android Auto, hosted fleet SaaS, paid SNAP/fuel APIs, legal cadastral LEZ polygons, TRAVIS booking integration, LEZ/lane depth chase unless UK wedge appears.

## Phase 30+ backlog (ranked)

1. **Full quarterly competitive re-scrape** — target **2026-11**; re-scrape Sygic / CoPilot / TomTom public pages; update research doc and scorecard if competitor deltas appear.
2. **CarPlay + WeatherKit entitlement restore** — same as Phase 28+ #1; blocked until paid team.
3. **Road closures (B4), roadworks GPS (B5), settings sub-menus (B6), DVLA scrape (B7)** — **B4/B5/B6 done** (Ph33–35); B7 DVLA scrape still deferred.
4. **Defer:** toll tariff tables, remote VU download, Android Auto, hosted fleet SaaS, paid SNAP/fuel APIs, legal cadastral LEZ polygons, TRAVIS booking integration.

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
- [x] Competitive intel refresh (Phase 20 public-web; **Phase 25/26 research docs**)
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
| Competitive intel refresh | CompetitiveIntel | **Done** — Phase 25/26 research docs + scorecard; **Ph29 positioning refresh** |
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
- [CoPilot TRAVIS integration](https://www.yourtravis.com/knowledge/trimble-integration/) *(2026-07-23)*
- Phase 26 research: [`competitive-research-2026-08.md`](competitive-research-2026-08.md)
