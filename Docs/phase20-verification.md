# Phase 20 — product verification

Date: 2026-08-27  
HEAD: `a4c36301` (pre-doc refresh)  
Environment: macOS + iPhone 17 Simulator; personal Apple team signing (`RouteFinderApp.xcodeproj`)

## Claim vs code inventory


| Claim area                        | Primary surfaces                                                                     | Verdict                                                          |
| --------------------------------- | ------------------------------------------------------------------------------------ | ---------------------------------------------------------------- |
| Constraint routing / ORS          | `RouteViewModel`, Settings ORS key, `OpenRouteServicePayloadBuilder`                 | Present                                                          |
| Physics rehearse + brief/PDF      | `rehearseRoute()`, `TripBriefPDFRenderer`, share menu                                | Present                                                          |
| HOS / tacho import / Can-I-drive  | HOS HUD, Settings import, `CanIDriveEvaluator`                                       | Present                                                          |
| Layby prediction + occupancy taps | `LaybyAdvisoryBanner`, `markCurrentLaybyFull` / `HasSpaces`, `LocalCrowdEventIngest` | Present                                                          |
| Fleet disk + LAN + SSE + Bonjour  | Dispatch console, Settings fleet, `RouteFinderFleetServer`, `FleetSSEClient`         | Present                                                          |
| Offline tiles / map pack          | Settings offline section, pack HTTP path                                             | Present                                                          |
| Weather OpenWeather path          | Settings OpenWeather key → `DefaultWeatherService` + hot-reload                      | Present                                                          |
| UK LEZ banners + avoid-on-route   | `UKLowEmissionZoneCatalog`, `LEZAvoidPolicy`                                         | Present — banners + ORS `avoid_polygons` (area + long-haul caps) |
| CarPlay                           | Code present; entitlements emptied for personal team                                 | **Degraded** — not device-QA’d on personal team                  |
| WeatherKit                        | Fallback when no OpenWeather key                                                     | **Degraded** on personal team (no entitlement)                   |




## Automated evidence


| Check                                             | Result                                                                  |
| ------------------------------------------------- | ----------------------------------------------------------------------- |
| `swift test` (package)                            | **Pass** — 435 tests (2026-08-28, Xcode-beta)                           |
| `xcodebuild` RouteFinderApp (iOS Simulator)       | **Pass** — BUILD SUCCEEDED                                              |
| Simulator cold launch (`Learning.RouteFinderApp`) | **Pass** — process started; no crash/fault in first ~8s of process logs |




## Structured QA checklist


| #   | Scenario                                       | Result                  | Notes                                                                                                                                                                                      |
| --- | ---------------------------------------------- | ----------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| 1   | Cold launch, map loads                         | **Pass** (smoke)        | Simulator launch succeeded; map tile path previously verified on personal-team device                                                                                                      |
| 2   | Geocode origin/destination, HGV route          | **Pass** (code + tests) | Full interactive ORS call not re-run in this pass; routing covered by package tests                                                                                                        |
| 3   | Rehearse → brief text + PDF share              | **Pass** (code + tests) | `rehearseRoute` + `TripBriefPDFRenderer` / snapshot tests green                                                                                                                            |
| 4   | Layby advisory; Looks full / Has spaces        | **Pass** (code + tests) | Phase 19 ingest → occupancy prior wired; UI handlers on map chrome                                                                                                                         |
| 5   | Save OpenWeather key → weather without restart | **Pass** (code + tests) | `weatherConfigurationDidChange` + `WeatherViewModel.replaceWeatherService`                                                                                                                 |
| 6   | Fleet local disk trip push                     | **Pass** (code + tests) | Disk store + dispatch VM covered by tests                                                                                                                                                  |
| 6b  | LAN Bonjour discover + SSE                     | **Pass (scripted)**     | Automated smoke: `[fleet-e2e-qa.md](fleet-e2e-qa.md)` Part A + `Scripts/fleet-e2e-smoke.sh`; live Mac↔phone checklist in Part B                                                            |
| 7   | HOS clock + inspection checklist open          | **Pass** (code + tests) | No crash paths in suite; checklist on disk                                                                                                                                                 |
| 8   | Known degraded paths                           | **Documented**          | CarPlay inactive (personal team entitlements); WeatherKit unavailable without paid team / OpenWeather key. Restore guide: `[carplay-weatherkit-restore.md](carplay-weatherkit-restore.md)` |




## Honest limits

- This is **evidence-based**, not a claim of flawless end-to-end driver QA on every path.
- Interactive map geocode + live ORS + live LAN Bonjour were not fully re-driven manually in this session; automation + launch smoke + code inventory stand in where noted.
- Do not claim production CarPlay QA on personal-team builds.



## Post-fix verification (2026-08-28)

HEAD: `8e70df66`  
Environment: macOS; `DEVELOPER_DIR=/Library/Developer/CommandLineTools` (full Xcode.app not installed — `xcodebuild` unavailable; packaged app used instead).

### Automated re-run


| Check                                                                                                     | Result                       | Notes                                                                                                                                                  |
| --------------------------------------------------------------------------------------------------------- | ---------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `swift test` (package)                                                                                    | **Pass** — 409 tests         | Full suite green                                                                                                                                       |
| Fix-specific unit tests (Keychain, geocode heuristic, LEZ long-haul cap, sim camera/zoom, curve governor) | **Pass** — 13 targeted tests | Filters on `KeychainStoreTests`, `OpenRouteServiceGeocoderTests`, `TruckPoiLivingLayerTests`, `MapViewControllerBridgeTests`, `CurveSpeedAdvisorTests` |
| `Scripts/package-macos-app.sh`                                                                            | **Pass**                     | Hardened codesign (`--options runtime`, inner-then-bundle, requires dev cert); `TeamIdentifier=GHBHLM9UAX`, `Runtime Version` present                  |
| `xcodebuild` RouteFinderMac                                                                               | **Skipped**                  | Full Xcode.app not installed in agent environment; use locally after `sudo xcode-select -s /Applications/Xcode.app/Contents/Developer`                 |




### Recent-fix smoke checklist


| #   | Scenario                               | Result               | Notes                                                                                                                                                                                                                                                             |
| --- | -------------------------------------- | -------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| K1  | RouteFinderMac Keychain — no re-prompt | **Pass**             | ORS key present in data-protection vault (`com.routefinder.vault.`*); consecutive Keychain reads return same credential; packaged app has `keychain-access-groups`. GUI relaunch not exercised in agent session — confirm locally with **RouteFinderMac** scheme. |
| G1  | `33 sørnesvegen` → Norway              | **Pass**             | Correct Ålesund address (prior QA used typo `sameswegen`, which is not a real place). Live Pelias global search returns Norway; overseas heuristic matches `vegen` after ø→o normalization.                                                                       |
| R1  | Long haul + LEZ avoid — no 2004        | **Pass**             | `lezAvoidPolicyOmitsPolygonsOnLongHaul` (Norwich → Ålesund); live ORS HGV route Norwich → Edinburgh (611 km) succeeds with no avoid polygons on long haul.                                                                                                        |
| S1  | 30 mph sim feel + centered camera      | **Pass** (automated) | `defaultTrackingZoom_isPulledBackForHGVFeel` (15.0), `cameraFollowCenter_offsetsForwardHalfLength`, `maxUpcomingCurveSpeedMps_nearStraightDensifiedSpineAllowsResidentialCruise`. Visual 30 mph feel / turn pivot: confirm via **RouteFinderMac** Xcode scheme.   |




### Honest limits (post-fix pass)

- **RouteFinderMac launch:** packaged `RouteFinder.app` from older `package-macos-app.sh` builds could crash with `Taskgated Invalid Signature` on macOS 26 (missing hardened runtime). Use Xcode **RouteFinderMac** scheme, or rebuild with the hardened package script.
- Visual sim feel (S1) and Keychain dialog absence (K1 relaunch) require local **RouteFinderMac** confirmation in Xcode.



### Sim UX + lane guidance (2026-08-28)


| #   | Scenario                               | Automated                                                                                                                 | Local confirm                                 |
| --- | -------------------------------------- | ------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------- |
| U1  | Session auto-unlock / pre-filled email | `SessionWorkspaceSettings` + `SessionController.bootstrap()` Touch ID path                                                | Relaunch twice — Touch ID or pre-filled login |
| U2  | Vehicle workspace restore              | `VehicleWorkspaceSettings` round-trip + `restoreVehicleWorkspace()` + persist on all sidebar/settings/control-sheet edits | Quit → relaunch — reg/dims/HGV mode persist   |
| U3  | 30 mph cruise (traffic off)            | `applyTrafficToSimulation` default false; physics uses posted limit only                                                  | Sim on 30 mph leg — dial ~30, not 24          |
| U4  | Center-anchored HGV polygon            | `renderMode` forces polygon while tracking; cab/trailer `footprintParts`                                                  | Turn at zoom 15 — body pivots from center     |
| U5  | Lane banner                            | `TurnLanesParserTests`, `LaneGuidanceEnricher`, `LaneGuidanceBanner` on map chrome                                        | Approach maneuver — lane strip on map top     |


`swift test`: **417+ tests** green (includes workspace settings round-trip, lane parser, footprint, and enricher cap/cache tests).

### Lane guidance hardening (2026-08-28)


| Check                | Result            | Notes                                                                                                                              |
| -------------------- | ----------------- | ---------------------------------------------------------------------------------------------------------------------------------- |
| Route find latency   | **Pass** (design) | Heuristics applied synchronously; Overpass capped to 8 maneuvers / 50 km in background                                             |
| Offline route parity | **Pass** (code)   | Offline tiled routes use heuristic lane guidance only (`queryOverpass: false`); online routes use capped async Overpass enrichment |
| Overpass cache       | **Pass** (unit)   | `OverpassLaneGuidanceCache` + `LaneGuidanceEnricherTests`                                                                          |
| U1–U5 interactive    | **Pending local** | Run **RouteFinderMac** in Xcode — automated coverage only in cloud agent                                                           |




## Critical bugs found

None blocking. No Phase 20 hotfix required.

## Phase 26 live QA (2026-08-28)

Market research push + wave 1 features (Break Now, LEZ v2, lane voice). **No CarPlay / WeatherKit.**


| #   | Scenario                                 | Persona     | Result                  | Notes                                                                                   |
| --- | ---------------------------------------- | ----------- | ----------------------- | --------------------------------------------------------------------------------------- |
| D1  | Norwich → Edinburgh HGV route + Rehearse | Owner-op    | **Pass** (code + tests) | Physics ETA + brief export paths covered by existing suite                              |
| D2  | Traffic reroute banner                   | Owner-op    | **Pass** (code + tests) | Standstill + alternate logic in `RouteViewModel`                                        |
| D3  | Break Now → layby rank                   | Owner-op    | **Pass** (unit)         | `predictBreakNow` + HUD `cup.and.saucer.fill` button; map centers via `focusMapOnLayby` |
| D4  | Lane banner + voice at junction          | Owner-op    | **Pass** (unit)         | `spokenLanePhrase` + prepare-tier prompt tests                                          |
| D5  | LEZ cross (London hop)                   | Owner-op    | **Pass** (unit)         | 11 zones; Euro-class copy in `announcementMessage`; long-haul avoid cap unchanged       |
| D6  | Mac dispatch push → iPhone SSE           | Small fleet | **Pass** (code + tests) | SSE hub + toast wired; live Mac↔phone not re-run this session                           |
| D7  | Bonjour discover fleet server            | Small fleet | **Pass (scripted)**     | `[fleet-e2e-qa.md](fleet-e2e-qa.md)` Part A automated + Part B manual checklist         |
| D8  | `swift test` full suite                  | Engineering | **Pass**                | 435 tests green with Xcode-beta `DEVELOPER_DIR`                                         |




### Phase 26 code surfaces


| Feature    | Primary files                                                                                                |
| ---------- | ------------------------------------------------------------------------------------------------------------ |
| Break Now  | `LaybyPredictionEngine.predictBreakNow`, `RouteViewModel.findBreakNow`, `IOSMapChrome` / `MapFirstShell` HUD |
| LEZ v2     | `UKLowEmissionZoneCatalog` (+5 zones), `announcementMessage` Euro copy, Settings explainer                   |
| Lane voice | `ManeuverSpeechFormatter.spokenLanePhrase`, prepare/execute tiers                                            |




### Automated evidence (Phase 26)


| Check                                              | Result            |
| -------------------------------------------------- | ----------------- |
| `LaybyOccupancyReportTests` Break Now + lane voice | **Pass**          |
| `TruckPoiLivingLayerTests` LEZ catalog expansion   | **Pass**          |
| Full `swift test`                                  | **Pass** (see D8) |




### Honest limits (Phase 26)

- Interactive Break Now tap-to-map-center not re-run on device this session; unit + code inventory stand in.
- TRAVIS parking booking intentionally not implemented — documented in research docs.
- CarPlay and WeatherKit remain out of scope.



### Phase 27c fleet E2E QA (2026-08-28)

HEAD: `315d39e9`  
Deliverables: `[Docs/fleet-e2e-qa.md](fleet-e2e-qa.md)`, `[RouteFinder/Scripts/fleet-e2e-smoke.sh](../RouteFinder/Scripts/fleet-e2e-smoke.sh)`, consolidated test `fleetE2EWorkflowPushSnapshotAndSSE`.


| Check                           | Result                                                                   |
| ------------------------------- | ------------------------------------------------------------------------ |
| `./Scripts/fleet-e2e-smoke.sh`  | **Pass** — HTTP push, SSE, Bonjour helpers, E2E workflow (9/9 filters)   |
| Manual Mac↔iPhone LAN (Part B)  | **Pending local** — checklist documented; run when two devices available |
| Demo dispatch fallback (Part C) | **Documented** — single-device path via Settings                         |




### Phase 28 ship hygiene (2026-08-28)

HEAD: `c9355a54`  
Scope: scorecard + verification doc refresh; CarPlay/WeatherKit restore **playbook only** (no entitlement merge on personal team).


| Check                                                                     | Result                                                       |
| ------------------------------------------------------------------------- | ------------------------------------------------------------ |
| Scorecard Ph27 gaps marked Done                                           | **Done**                                                     |
| `[carplay-weatherkit-restore.md](carplay-weatherkit-restore.md)` playbook | **Done** — execute only on paid Apple Developer Program team |
| Full `swift test`                                                         | **Pass** — 435 tests (Xcode-beta)                            |




### Phase 29 competitive positioning refresh (2026-08-28)

HEAD: `8c464ee`  
Scope: light positioning refresh — no code, entitlements, or Firecrawl re-scrape.


| Check                                                                                                          | Result                                                                                     |
| -------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------ |
| `[competitive-research-2026-08.md](competitive-research-2026-08.md)` executive summary + Post-Ph27 sales lines | **Done**                                                                                   |
| `[competitive-feature-scorecard.md](competitive-feature-scorecard.md)` Phase 29 wave-complete note             | **Done**                                                                                   |
| `[competitive-gap-matrix.md](competitive-gap-matrix.md)` Ph28+ #2 Done; Ph30+ next scrape **2026-11**          | **Done**                                                                                   |
| Full competitor re-scrape                                                                                      | **Deferred** — next quarterly cycle (2026-11)                                              |
| Manual Mac↔iPhone LAN (Fleet Part B)                                                                           | **Pending local** — `[fleet-e2e-qa.md](fleet-e2e-qa.md)` Part B                            |
| Interactive Mac app (U1–U5)                                                                                    | **Pending local**                                                                          |
| CarPlay + WeatherKit restore                                                                                   | **Blocked — paid team** — `[carplay-weatherkit-restore.md](carplay-weatherkit-restore.md)` |




### iOS map load hardening (2026-08-28)

Scope: fix white-screen launch on iPhone when MapLibre WKWebView fails silently (CDN race, broken local map pack, WebContent process kill).


| Check                                                          | Result                                                                                                                                                                                           |
| -------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `bootMap` retry + `setMapStyle` hot-reload + JS error bridge   | **Done** — `[MapLibreMapHTML.swift](../RouteFinder/Sources/MapLibreUI/MapLibreMapHTML.swift)`, `[MapLibreWebMapView.swift](../RouteFinder/Sources/MapLibreUI/MapLibreWebMapView.swift)`          |
| Loading spinner + error/retry/online fallback overlay          | **Done**                                                                                                                                                                                         |
| Local map style default **off**; invalid `style.json` rejected | **Done** — `[VehicleProfileStore.swift](../RouteFinder/Sources/DataLayer/VehicleProfileStore.swift)`, `[OfflineMapPackStore.swift](../RouteFinder/Sources/MapLibreUI/OfflineMapPackStore.swift)` |
| Bundled `maplibre-gl.js/css` in `RouteFinderApp`               | **Done** — iOS uses loopback `MapBootstrapServer` + bundled assets; macOS uses file `baseURL` + relative script refs                                                                             |
| `RouteFinderApp` location/motion privacy keys                  | **Done** — `NSLocationWhenInUseUsageDescription`, `NSLocationAlwaysAndWhenInUseUsageDescription`, `NSMotionUsageDescription` in `[RouteFinderApp/Info.plist](../RouteFinderApp/Info.plist)`      |
| iOS login gate via `RootAuthContainer`                         | **Done** — `[RouteFinderAppApp.swift](../RouteFinderApp/RouteFinderAppApp.swift)`                                                                                                                |
| Walkaround discoverability + onboarding liability              | **Done** — default HGV mode on iOS, toolbar shortcut, liability acceptance in onboarding                                                                                                         |
| WebContent terminate reload cap                                | **Done** — max 2 automatic reloads in `[MapLibreWebMapView.swift](../RouteFinder/Sources/MapLibreUI/MapLibreWebMapView.swift)`                                                                   |
| `RouteFinderApp` AppDelegate CarPlay scene config              | **Done** — matches `[RouteFinderIOS/AppDelegate.swift](../RouteFinder/Sources/RouteFinderIOS/AppDelegate.swift)`                                                                                 |
| Device iPhone stays open + map visible on launch               | **Pending local** — delete app, rebuild `RouteFinderApp` on physical iPhone                                                                                                                      |




### Phase A iOS device QA (2026-08-28)

Run on a **physical iPhone** before treating Phase 30+ as fully verified (personal-team signing).


| #   | Scenario                                                    | Result                      | Notes                                                               |
| --- | ----------------------------------------------------------- | --------------------------- | ------------------------------------------------------------------- |
| A1  | Delete RouteFinderApp from device                           | **Pending local**           | Ensures clean Keychain + UserDefaults                               |
| A2  | Xcode → Clean Build Folder → run `RouteFinderApp` to device | **Pending local**           | Use `RouteFinderApp.xcodeproj` scheme                               |
| A3  | Login screen appears on cold launch                         | **Pass** (code)             | `RootAuthContainer` gate wired in `RouteFinderAppApp.swift`         |
| A4  | Liability onboarding → accept → map loads tiles             | **Pass** (code + sim smoke) | `MapBootstrapServer` loopback; physical tile load **Pending local** |
| A5  | ⋯ toolbar → Walkaround check opens zoned checklist          | **Pass** (code)             | Default HGV mode on iOS; interactive **Pending local**              |
| A6  | On failure: capture device log                              | **N/A**                     | Look for `SIGABRT`, `WebKit`, `Jetsam` in Console                   |


**Automated gate (2026-08-29):** **Ph45–48 reliability economics program** — `swift test` green (~504 cases across targets); fleet E2E smoke in CI; API usage ledger + soft budget guards; unified `RemoteRequestPolicy`; fleet + hazard coordinators extracted from `RouteViewModel`. Physical device execution of **C1–C9** deferred until after reliability gate — **Pending local** (~20 min checklist).

### Phase 43–44 CI fix + dispatch defect toast (2026-08-29)

Scope: repo-root GitHub Actions workflow, dispatch poll toast when inspection defects arrive.


| #     | Scenario                                                       | Automated       | Local confirm                                                    |
| ----- | -------------------------------------------------------------- | --------------- | ---------------------------------------------------------------- |
| P43-1 | CI workflow at repo root with `RouteFinder/` working directory | **Pass** (code) | `[.github/workflows/ci.yml](../.github/workflows/ci.yml)`        |
| P43-2 | `swift test` runs from package directory in CI                 | **Pass** (code) | macos job `working-directory: RouteFinder`                       |
| P43-3 | RouteFinderApp UI smoke in CI with simulator fallback          | **Pass** (code) | ios job `xcodebuild test`                                        |
| P44-1 | Dispatch toast when poll detects new walkaround defects        | **Pass** (unit) | `DispatchInspectionAnnouncerTests`                               |
| P44-2 | Dispatch console shows defect card + toast on LAN poll         | **Pass** (code) | `DispatchViewModel.refreshActiveTrip` — **Pending local** Part B |




### Phase 45–48 reliability economics program (2026-08-29)

Scope: API unit economics metering, remote request policy, coordinator decomposition, reliability SLO gate.


| #     | SLO / evidence                                   | Automated        | Notes                                    |
| ----- | ------------------------------------------------ | ---------------- | ---------------------------------------- |
| P45-1 | `APIUsageLedger` daily roll-up + persistence     | **Pass** (unit)  | `APIUsageLedgerTests`                    |
| P45-2 | Soft budget skips TomTom / Overpass polls        | **Pass** (unit)  | `allowsNonCriticalRequest`               |
| P45-3 | Settings “API Usage Today” panel                 | **Pass** (code)  | `SettingsSheet.apiUsageSection`          |
| P45-4 | Unit economics doc                               | **Pass** (doc)   | `[unit-economics.md](unit-economics.md)` |
| P46-1 | `RemoteRequestPolicy` retry / 429 / backoff      | **Pass** (unit)  | `RemoteRequestPolicyTests`               |
| P46-2 | ORS / TomTom / fleet HTTP use policy             | **Pass** (code)  | Client boundaries instrumented           |
| P46-3 | Geocoder `print` → `RouteFinderLog.geocode`      | **Pass** (code)  | `OpenRouteServiceGeocoder`               |
| P46-4 | Fleet E2E smoke in CI macos job                  | **Pass** (code)  | `Scripts/fleet-e2e-smoke.sh`             |
| P47-1 | `FleetDispatchCoordinator` + integration test    | **Pass** (unit)  | `FleetDispatchCoordinatorTests`          |
| P47-2 | `HazardNavigationCoordinator` + integration test | **Pass** (unit)  | `HazardNavigationCoordinatorTests`       |
| P47-3 | Architecture ADR                                 | **Pass** (doc)   | `[architecture.md](architecture.md)`     |
| P48-1 | `swift test` 100% on PR                          | **Pass** (local) | All targets green 2026-08-29             |
| P48-2 | UI smoke 3 tests (ios CI job)                    | **Pass** (code)  | Unchanged from Ph43                      |
| P48-3 | iPhone C1–C9 device QA                           | **Unblocked**    | See Phase 49b — still **Pending local**  |




### Phase 49a — CI green (MapKit Sendable) (2026-08-29)

Scope: restore macOS CI after Swift 6 / MapKit concurrency failure on `macos-15` Xcode 16.4.


| #      | SLO / evidence                    | Automated        | Notes                                                                                                                           |
| ------ | --------------------------------- | ---------------- | ------------------------------------------------------------------------------------------------------------------------------- |
| P49a-1 | `swift build -c release` succeeds | **Pass** (local) | `@preconcurrency import MapKit` in `AppleGeocodeSearch`                                                                         |
| P49a-2 | `swift test` green                | **Pass** (local) | All package targets                                                                                                             |
| P49a-3 | Fleet E2E smoke                   | **Pass** (local) | `Scripts/fleet-e2e-smoke.sh` 9/9                                                                                                |
| P49a-4 | GitHub Actions macos + ios        | **Pass** (CI)    | [run 33253641183](https://github.com/thesnjk/RouteFinder/actions/runs/33253641183) on `8f4ff6ee` (MapKit + CLGeocoder Sendable) |




#### Phase 49a code surfaces


| Feature                 | Primary files                                                        |
| ----------------------- | -------------------------------------------------------------------- |
| MapKit Sendable fix     | `AppleGeocodeSearch.swift`                                           |
| CLGeocoder Sendable fix | `LocationResolver.swift` (`@preconcurrency` + `nonisolated(unsafe)`) |




### Phase 49c — Fleet SSE CI flake hardening (2026-08-29)

Scope: replace fixed 300 ms server startup sleeps with health-endpoint polling so Hummingbird bind races do not fail CI.


| #      | SLO / evidence                                         | Automated        | Notes                          |
| ------ | ------------------------------------------------------ | ---------------- | ------------------------------ |
| P49c-1 | `waitForFleetServerReady` polls `GET /health`          | **Pass** (code)  | `FleetTestServerSupport.swift` |
| P49c-2 | Fleet SSE / Auth / HTTP LAN tests use readiness helper | **Pass** (code)  | No fixed 300 ms startup sleep  |
| P49c-3 | Fleet E2E smoke                                        | **Pass** (local) | `Scripts/fleet-e2e-smoke.sh`   |




#### Phase 49c code surfaces


| Feature               | Primary files                                                                            |
| --------------------- | ---------------------------------------------------------------------------------------- |
| Server readiness poll | `FleetTestServerSupport.swift`, `FleetSSETests`, `FleetAuthTests`, `HTTPFleetStoreTests` |




### Phase 50 — Route planning coordinator (2026-08-29)

Scope: extract route-planning helpers and async orchestration from `RouteViewModel`.


| #     | SLO / evidence                                                                | Automated       | Notes                                                 |
| ----- | ----------------------------------------------------------------------------- | --------------- | ----------------------------------------------------- |
| P50-1 | `RoutePlanningCoordinator` + `RoutePlanningHost`                              | **Pass** (code) | SearchResult mapping, LEZ rings, failure presentation |
| P50-2 | Recalculate debounce / lane enrichment / traffic reroute owned by coordinator | **Pass** (code) | Tasks moved off `RouteViewModel`                      |
| P50-3 | Coordinator integration tests                                                 | **Pass** (unit) | `RoutePlanningCoordinatorTests`                       |




#### Phase 50 code surfaces


| Feature                    | Primary files                                                            |
| -------------------------- | ------------------------------------------------------------------------ |
| Route planning coordinator | `RoutePlanningCoordinator.swift`, `RouteViewModel` (`RoutePlanningHost`) |




### Phase 51 — Route simulation coordinator (2026-08-29)

Scope: extract simulation callbacks, kinetic advisories, physics ETA/rehearse, and Break Now from `RouteViewModel`.


| #     | SLO / evidence                                               | Automated       | Notes                             |
| ----- | ------------------------------------------------------------ | --------------- | --------------------------------- |
| P51-1 | `RouteSimulationCoordinator` + `RouteSimulationHost`         | **Pass** (code) | Callbacks, kinetic, camera zoom   |
| P51-2 | Physics estimate / rehearse / Break Now owned by coordinator | **Pass** (code) | Tasks moved off `RouteViewModel`  |
| P51-3 | Coordinator integration tests                                | **Pass** (unit) | `RouteSimulationCoordinatorTests` |




#### Phase 51 code surfaces


| Feature                | Primary files                                                                |
| ---------------------- | ---------------------------------------------------------------------------- |
| Simulation coordinator | `RouteSimulationCoordinator.swift`, `RouteViewModel` (`RouteSimulationHost`) |




### Phase 52 — HOS advisory coordinator (2026-08-29)

Scope: extract HOS clock, tacho import, and rest forecast orchestration from `RouteViewModel`.


| #     | SLO / evidence                                    | Automated       | Notes                                       |
| ----- | ------------------------------------------------- | --------------- | ------------------------------------------- |
| P52-1 | `HosAdvisoryCoordinator` + `HosAdvisoryHost`      | **Pass** (code) | Transitions, can-I-drive, tacho persistence |
| P52-2 | Rest forecast + path metrics owned by coordinator | **Pass** (code) | `hosPath`* helpers moved                    |
| P52-3 | Coordinator integration tests                     | **Pass** (unit) | `HosAdvisoryCoordinatorTests`               |




#### Phase 52 code surfaces


| Feature                  | Primary files                                                        |
| ------------------------ | -------------------------------------------------------------------- |
| HOS advisory coordinator | `HosAdvisoryCoordinator.swift`, `RouteViewModel` (`HosAdvisoryHost`) |




### Phase 49b — Device validation gate (2026-08-29)

Reliability gate (Ph48) + CI green (Ph49a/Ph51–52 wave) are complete. **Physical iPhone C1–C9 and Fleet Part B remain operator-run** (~30–40 min). Agent cannot execute device QA; checklist is ready. **Do not start fleet pitching until P0 Pass.**

**P0 first (~10 min):** C1–C2 (cold install, login, map tiles, **Driver Terms** acceptance) then C8 (Settings hub including **API Usage Today** + **Legal → Driver Terms**). Mark Pass/Fail in the consolidated C1–C9 table below when run.

#### Operator P0 runbook (physical iPhone)

1. Unlock iPhone + plug USB (UDID `00008101-000E6C41226A001E` was Offline on 2026-08-29).
2. Delete RouteFinder from the phone.
3. Xcode → open `RouteFinderApp.xcodeproj` → scheme **RouteFinderApp** → destination = your iPhone → **Product → Clean Build Folder** → **Run**.
4. Log in → accept **Driver Terms** (confirm sheet cannot swipe-dismiss) → confirm map tiles load (tap **Retry** / **Use online map** if basemap fails).
5. ⋯ → Settings → **API Keys**:
  - Paste HeiGIT OpenRouteService key → tap **Save API Key** (typing alone does not save).
  - Confirm **Saved in Keychain as ••••••••** and green **HeiGIT API key saved**.
  - Confirm **API Usage Today** loads → back → **Legal** (Driver Terms).
6. Dismiss Settings → confirm the orange **Cloud routing — add API key** banner is **gone**.
7. Search: start `London`, destination `Manchester` → **Find route** → expect polyline + ETA (screenshot any failure modal).
8. Edit this file: set C1, C2, C8, and P49b-P0 to **Pass** or **Fail**.

**Then P1 / P2 / Fleet:** C3, C6–C7, C9 → C4–C5 → Fleet Part B LAN (`[fleet-e2e-qa.md](fleet-e2e-qa.md)`). After P0: book meetings via `[pilot-outreach.md](pilot-outreach.md)`.


| #       | Scenario                                          | Result            | Notes                                                                            |
| ------- | ------------------------------------------------- | ----------------- | -------------------------------------------------------------------------------- |
| P49b-P0 | C1–C2 + C8 physical iPhone                        | **Pending local** | Operator — includes Save API Key + London→Manchester after Ph54                  |
| P49b-1  | C1–C9 physical iPhone checklist                   | **Pending local** | Full table below                                                                 |
| P49b-2  | Fleet Part B LAN walkaround → dispatch inspection | **Pending local** | Part A smoke **Pass** local 2026-08-29 (9/9); Part B needs phone on same Wi‑Fi   |
| P49b-3  | Settings API Usage Today + Legal Driver Terms     | **Pass** (sim)    | `testSettingsAPIUsageAndLegalDriverTerms` green 2026-08-29; physical still in C8 |




### Phase 54 — iOS routing UX unblock (2026-08-29)

Scope: fix misleading cloud banner, ORS save confirmation, iOS auth/Settings copy, basemap retry / clearer errors.


| #     | SLO / evidence                                            | Automated         | Notes                                                         |
| ----- | --------------------------------------------------------- | ----------------- | ------------------------------------------------------------- |
| P54-1 | Cloud banner uses status / hides when keyed               | **Pass** (code)   | `showCloudRoutingStatusBanner`; nag only when `!hasORSAPIKey` |
| P54-2 | Save API Key shows green confirmation                     | **Pass** (code)   | `settingsSaveConfirmation` + `settingsORSAPIKeySaved`         |
| P54-3 | iOS auth/Settings copy says “this device”                 | **Pass** (code)   | `AuthGateView`, ORS help text                                 |
| P54-4 | Basemap network error auto-retries once + clearer overlay | **Pass** (code)   | `MapLibreWebMapView` style network retry                      |
| P54-5 | Offline Settings footnote when no tiles                   | **Pass** (code)   | Orange note under Prefer offline                              |
| P54-6 | Device: Save key + map tiles + London→Manchester          | **Pending local** | Operator — see P0 runbook steps 4–7                           |




#### Phase 54 code surfaces


| Feature            | Primary files                                                               |
| ------------------ | --------------------------------------------------------------------------- |
| Cloud banner       | `IOSMapChrome`, `RouteViewModel.showCloudRoutingStatusBanner`               |
| Save feedback      | `SettingsSheet.orsAPIKeySection`, `RouteViewModel.settingsSaveConfirmation` |
| Basemap resilience | `MapLibreWebMapView`                                                        |




### Phase 53 — Pilot GTM prep (2026-08-29)

Scope: strengthen Driver Terms, ship pilot pack / outreach / feedback backlog docs. Physical pilots remain operator-run.


| #     | SLO / evidence                                                    | Automated             | Notes                                                                                                                  |
| ----- | ----------------------------------------------------------------- | --------------------- | ---------------------------------------------------------------------------------------------------------------------- |
| P53-1 | Driver Terms bridge-strike wording + non-dismissible first launch | **Pass** (code)       | `ProductOnboardingSheet`, `ContentView.interactiveDismissDisabled`                                                     |
| P53-2 | Settings → Legal shows Driver Terms                               | **Pass** (code + sim) | `SettingsSheet.legalSection` + UI smoke                                                                                |
| P53-3 | Pilot pack (agreement, API, checklist, feedback form)             | **Pass** (doc)        | `[pilot-fleet-pack.md](pilot-fleet-pack.md)`                                                                           |
| P53-4 | Outreach script + target table                                    | **Pass** (doc)        | `[pilot-outreach.md](pilot-outreach.md)` — 5 draft targets filled; send after P0                                       |
| P53-5 | Feedback triage backlog template                                  | **Pass** (doc)        | `[pilot-feedback-backlog.md](pilot-feedback-backlog.md)` — fill after week 2                                           |
| P53-6 | CI green for Driver Terms + pilot pack commit                     | **Pass** (CI)         | [run 33260215759](https://github.com/thesnjk/RouteFinder/actions/runs/33260215759) on `3536134a` — macos + ios success |




#### Phase 53 code / doc surfaces


| Feature      | Primary files                                                                          |
| ------------ | -------------------------------------------------------------------------------------- |
| Driver Terms | `ProductOnboardingSheet`, `ContentView`, `SettingsSheet`                               |
| Pilot pack   | `Docs/pilot-fleet-pack.md`, `Docs/pilot-outreach.md`, `Docs/pilot-feedback-backlog.md` |




#### Phase 45–48 code surfaces


| Feature            | Primary files                                                       |
| ------------------ | ------------------------------------------------------------------- |
| API metering       | `APIUsageModels`, `APIUsageLedger`, `SettingsSheet.apiUsageSection` |
| Remote policy      | `RemoteRequestPolicy`, `RouteFinderLog`                             |
| Fleet coordinator  | `FleetDispatchCoordinator`, `RouteViewModel` (`FleetDispatchHost`)  |
| Hazard coordinator | `HazardNavigationCoordinator`, `HazardNavigationState`              |




#### Phase 43–44 code surfaces


| Feature               | Primary files                                                                        |
| --------------------- | ------------------------------------------------------------------------------------ |
| Repo-root CI          | `.github/workflows/ci.yml`                                                           |
| Dispatch defect toast | `DispatchInspectionAnnouncer`, `DispatchViewModel.announceInspectionDefectsIfNeeded` |




### Phase 41–42 dispatch inspection + CI (2026-08-29)

Scope: dispatch console walkaround defect visibility, fleet LAN inspection snapshot round-trip, CI UI smoke.


| #     | Scenario                                                        | Automated       | Local confirm                                                                 |
| ----- | --------------------------------------------------------------- | --------------- | ----------------------------------------------------------------------------- |
| P41-1 | Dispatch shows walkaround defect card when snapshot has defects | **Pass** (code) | `DispatchStatusPanel.inspectionWarningCard`                                   |
| P41-2 | Dispatch PDF share from inspection base64 on trip               | **Pass** (code) | ShareLink on defect card                                                      |
| P41-3 | Trip brief share visible when inspection-only snapshot          | **Pass** (code) | `showsTripBriefShare` in dispatch header                                      |
| P42-1 | Fleet E2E snapshot carries inspection summary + PDF             | **Pass** (unit) | `fleetE2EWorkflowPushSnapshotAndSSE`                                          |
| P42-2 | RouteFinderApp UI smoke in CI                                   | **Pass** (code) | `[.github/workflows/ci.yml](../.github/workflows/ci.yml)` ios job (repo root) |
| P42-3 | Fleet Part B walkaround → dispatch inspection                   | **Pass** (doc)  | `[fleet-e2e-qa.md](fleet-e2e-qa.md)` step 9 — **Pending local**               |




#### Phase 41–42 code surfaces


| Feature                | Primary files                                                                      |
| ---------------------- | ---------------------------------------------------------------------------------- |
| Dispatch inspection UI | `DispatchStatusPanel`, `FleetTrip.latestInspectionSummary`                         |
| Fleet inspection E2E   | `FleetSSETests.fleetE2EWorkflowPushSnapshotAndSSE`                                 |
| CI UI smoke            | `[.github/workflows/ci.yml](../.github/workflows/ci.yml)`, `RouteFinderAppUITests` |




### Phase 38–40 automation & fleet handoff (2026-08-28)

Scope: iOS XCTest smoke, walkaround defect line in trip brief + optional fleet PDF snapshot, hazard overlay rebuild on crowd hydrate.


| #     | Scenario                                                | Automated          | Local confirm                                                               |
| ----- | ------------------------------------------------------- | ------------------ | --------------------------------------------------------------------------- |
| P38-1 | Cold launch shows auth or map chrome                    | **Pass** (UI test) | `RouteFinderAppUITests.testColdLaunchShowsAuthOrMap`                        |
| P38-2 | Settings hub → Vehicle & HGV row                        | **Pass** (UI test) | `testSettingsHubOpens` with `UITEST_SKIP_AUTH`                              |
| P38-3 | HGV toolbar exposes walkaround entry                    | **Pass** (UI test) | `testWalkaroundEntryExists`                                                 |
| P39-1 | Trip brief includes inspection warning when defects > 0 | **Pass** (unit)    | `TripBriefFormatterTests`                                                   |
| P39-2 | Fleet snapshot carries inspection PDF base64            | **Pass** (code)    | `RouteViewModel.publishInspectionFleetHandoff` when remote fleet configured |
| P40-1 | Hazard overlay rebuild from promoted hazards            | **Pass** (unit)    | `HazardOverlayBuilderTests`                                                 |
| P40-2 | Crowd hydrate restores map pins after relaunch          | **Pass** (code)    | `hydrateCrowdReportsFromDisk` + `HazardOverlayBuilder`                      |




#### Running Phase 38 UI tests

```bash
# In Xcode: Product → Test (RouteFinderApp scheme, iPhone simulator)
# Or: xcodebuild test -project RouteFinderApp.xcodeproj -scheme RouteFinderApp \
#   -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:RouteFinderAppUITests
```

Launch arguments used by smoke tests: `UITEST_SKIP_AUTH`, `UITEST_SKIP_ONBOARDING`.

#### Phase 38–40 code surfaces


| Feature                | Primary files                                                                                                             |
| ---------------------- | ------------------------------------------------------------------------------------------------------------------------- |
| XCTest smoke           | `RouteFinderAppUITests`, `UITestLaunchConfigurator`, accessibility IDs in `AuthGateView`, `SettingsSheet`, `IOSMapChrome` |
| Walkaround trip brief  | `TripBriefInspectionSummary`, `TripBriefFormatter`, `RouteViewModel.saveActiveInspection`                                 |
| Fleet inspection PDF   | `FleetTripSnapshot.inspectionReportPDFBase64`, `FleetTrip.latestInspectionSummary`                                        |
| Hazard overlay rebuild | `HazardOverlayBuilder`, `hydrateCrowdReportsFromDisk`                                                                     |




### Consolidated iPhone device QA — Phase A + Ph30–35 (2026-08-28)

Run once on a **physical iPhone** after each major driver-facing wave.


| #   | Scenario                                                 | Result                                      | Notes                                                                                    |
| --- | -------------------------------------------------------- | ------------------------------------------- | ---------------------------------------------------------------------------------------- |
| C1  | Delete app → Clean Build → run to device                 | **Pending local**                           | P0 — phone Offline 2026-08-29; sim cold launch covered by `testColdLaunchShowsAuthOrMap` |
| C2  | Login → Driver Terms → map tiles (no sandbox error)      | **Pending local**                           | P0 + Ph54 — Retry / Use online map; then Save ORS key + London→Manchester                |
| C3  | Walkaround v2: zones, defect note, PDF share             | **Pending local**                           | Phase 31; P1 — toolbar entry covered by `testWalkaroundEntryExists` (sim)                |
| C4  | Layby voice alert on HGV route (Settings on)             | **Pending local**                           | Phase 30; P2                                                                             |
| C5  | Fuel card picker → ahead banner on route                 | **Pending local**                           | Phase 32; P2                                                                             |
| C6  | Report closure → hazard ahead banner + voice             | **Pending local**                           | Phase 33; P1                                                                             |
| C7  | Roadworks ahead banner (OSM construction corridor)       | **Pending local**                           | Phase 35; P1                                                                             |
| C8  | Settings hub drill-down (API Usage + Legal Driver Terms) | **Pass** (sim) / **Pending local** (device) | `testSettingsAPIUsageAndLegalDriverTerms`; re-confirm on phone                           |
| C9  | TomTom key set → live traffic hazard ahead during nav    | **Pending local**                           | Phase 36; requires TomTom API key; P1                                                    |




### Phase 30–32 driver-facing wins (2026-08-28)

Scope: layby proactive alerts, comprehensive walkaround v2, fuel card provider advisory.


| #     | Scenario                                                | Automated              | Local confirm                                                                  |
| ----- | ------------------------------------------------------- | ---------------------- | ------------------------------------------------------------------------------ |
| P30-1 | Layby voice announce once inside 5 km                   | **Pass** (unit)        | `LaybyAlertFormatterTests`, Settings "Layby voice alerts" toggle               |
| P30-2 | "Looks full" → toast with next layby                    | **Pass** (unit)        | `LaybyAlertFormatter.nextLaybyToast`                                           |
| P30-3 | GPS navigation refreshes layby advisory (10 s throttle) | **Pass** (code)        | `LaybyRefreshNavigationAdapter` in `RouteViewModel`                            |
| P31-1 | Zoned checklist covers 7 DVSA zones (~24 items)         | **Pass** (unit)        | `InspectionRecordTests.defaultDVSAItemsCoverAllZones`                          |
| P31-2 | Defect note field + completion gate blocks Save         | **Pass** (code)        | `InspectionWalkaroundSheet`, `isReadyToSave`                                   |
| P31-3 | PDF report renders and shares                           | **Pass** (unit)        | `InspectionReportPDFRendererTests`                                             |
| P32-1 | Fuel card provider picker persists                      | **Pass** (unit)        | `NavigationWorkspaceSettingsTests.fuelCardProviderDefaultsToNoneAndRoundTrips` |
| P32-2 | Brand/name match highlights ahead fuel POIs             | **Pass** (unit)        | `FuelCardMatcherTests`                                                         |
| P32-3 | Ahead banner "Accepts your {provider} card"             | **Pass** (unit + code) | `TruckPoiAheadList` + Settings picker                                          |




#### Phase 30–32 code surfaces


| Feature             | Primary files                                                                                                         |
| ------------------- | --------------------------------------------------------------------------------------------------------------------- |
| Layby voice + toast | `LaybyAlertFormatter`, `VoiceGuidanceCoordinator.speakLaybyAdvisory`, `RouteViewModel.processLaybyVoiceAlertIfNeeded` |
| Walkaround v2       | `InspectionZone`, `InspectionRecord.defaultDVSAItems`, `InspectionWalkaroundSheet`, `InspectionReportPDFRenderer`     |
| Fuel card advisory  | `FuelCardProvider`, `FuelCardMatcher`, `TruckPoiAheadList`, Settings picker                                           |




#### Automated evidence (Phase 30–32)


| Check                                                        | Result                                             |
| ------------------------------------------------------------ | -------------------------------------------------- |
| `LaybyAlertFormatterTests`                                   | **Pass**                                           |
| `InspectionRecordTests` + `InspectionReportPDFRendererTests` | **Pass**                                           |
| `FuelCardMatcherTests` + fuel card settings round-trip       | **Pass**                                           |
| Full `swift test`                                            | **Pass** — includes Ph33–35 hazard/roadworks tests |




### Phase 33–35 driver alerts & settings (2026-08-28)

Scope: live closure/traffic hazard ahead alerts, Settings hub sub-menus, OSM roadworks-ahead banner.


| #     | Scenario                                   | Automated       | Local confirm                                        |
| ----- | ------------------------------------------ | --------------- | ---------------------------------------------------- |
| P33-1 | Closure hazard announce-once inside 3 km   | **Pass** (unit) | `HazardAheadFormatterTests`                          |
| P33-2 | Hazard ahead banner on map chrome          | **Pass** (code) | `HazardAheadBanner` + crowd report → `activeHazards` |
| P33-3 | Settings "Closure & traffic alerts" toggle | **Pass** (unit) | `NavigationWorkspaceSettingsTests`                   |
| P34-1 | Settings hub → drill-down sub-menus        | **Pass** (code) | `SettingsSheet` NavigationLink groups                |
| P35-1 | OSM roadworks parsed from fixture          | **Pass** (unit) | `RoadworksAlongRouteRepositoryTests`                 |
| P35-2 | Roadworks ahead banner on active route     | **Pass** (code) | `RoadworksAheadBanner` + `loadRoadworksAlongRoute`   |




#### Phase 33–35 code surfaces


| Feature             | Primary files                                                                                |
| ------------------- | -------------------------------------------------------------------------------------------- |
| Hazard ahead alerts | `HazardAheadFormatter`, `HazardAheadBanner`, `RouteViewModel.refreshHazardAheadAnnouncement` |
| Settings hub        | `SettingsSheet` NavigationLink drill-down                                                    |
| Roadworks ahead     | `RoadworkSite`, `RoadworksAlongRouteRepository`, `RoadworksAheadBanner`                      |




### Phase 36 hazard hardening (2026-08-28)

Scope: TomTom live traffic/closure ahead sampling, crowd hazard hydration, roadworks disk cache.


| #     | Scenario                                          | Automated       | Local confirm                                                      |
| ----- | ------------------------------------------------- | --------------- | ------------------------------------------------------------------ |
| P36-1 | TomTom hit merges with crowd hazard; nearest wins | **Pass** (unit) | `HazardAheadFormatterTests.tomTomHitWinsWhenCloserThanCrowdHazard` |
| P36-2 | Live sampler throttled at 30 s                    | **Pass** (unit) | `LiveTrafficHazardSamplerTests.shouldPollRespectsInterval`         |
| P36-3 | Crowd reports hydrate into promoted hazards       | **Pass** (unit) | `HazardAheadFormatter.promotedHazards`                             |
| P36-4 | Roadworks disk cache round-trip                   | **Pass** (unit) | `RoadworksDiskCacheTests`                                          |
| P36-5 | TomTom key → live traffic banner during GPS nav   | **Pass** (code) | **Pending local** — row C9                                         |




#### Phase 36 code surfaces


| Feature            | Primary files                                                                                          |
| ------------------ | ------------------------------------------------------------------------------------------------------ |
| TomTom live hazard | `LiveTrafficHazardSampler`, `TomTomTrafficHazardHit`, `RouteViewModel.sampleTomTomHazardAheadIfNeeded` |
| Crowd hydrate      | `HazardAheadFormatter.promotedHazards`, `hydrateCrowdReportsFromDisk`                                  |
| Roadworks cache    | `RoadworksDiskCache`, cached `RoadworksAlongRouteRepository`                                           |


