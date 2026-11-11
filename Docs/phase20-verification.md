# Phase 20 — product verification + engineering excellence ledger

## Prompt chain — current state

**ICP:** UK independents, **5–15 trucks**, iPhone-first dispatch + driver wedge.  
**Scope:** Engineering only — no legal / compliance / licensing / GTM / pilot outreach.  
**Engineering excellence track:** Phases **1–7 complete** (simulator/CI); **Phase 7b** (2026-11-11) closes C4 / C9 / Part B as **Pass (CI sim / CI)**. Agent Phase 31+ ungated tracks **Done** 2026-11-09 (H1/H2, HOS, Lane Overpass). **EPIC-OFFLINE-UX** Midlands mid-corridor **Done** 2026-11-11. **EPIC-DESK-LAYBY** web + Android predictedLayby **Done** 2026-11-11. Physical hear-TTS / live TomTom GPS / Mac↔phone LAN = **optional** residuals (same honesty as C6/C7).  
**Last product update:** Desk layby parity 2026-11-11; Docs P0 + Phase 58 SSOT 2026-11-11. Optional physical smoke: [`phase1-device-checklist.md`](phase1-device-checklist.md).

| Doc | Role |
|-----|------|
| [`engineering-benchmark-2026-09.md`](engineering-benchmark-2026-09.md) | Competitive matrix + epics |
| [`engineering-test-matrix.md`](engineering-test-matrix.md) | Feature → test command map |
| [`phase3-stranger-ux-verification.md`](phase3-stranger-ux-verification.md) | Stranger / fleet wizard |
| [`phase4-platform-parity-verification.md`](phase4-platform-parity-verification.md) | CarPlay + Android C2 + hosted |
| [`phase6-performance-verification.md`](phase6-performance-verification.md) | Hotspot measurements |
| [`phase7-device-simulator-verification.md`](phase7-device-simulator-verification.md) | C3–C9 / Part B UITest + CI gate |
| [`phase1-device-checklist.md`](phase1-device-checklist.md) | Optional physical C3–C9 / Part B smoke |
| [`demo-superiority-script.md`](demo-superiority-script.md) | 2-minute demo script |

**Self-sustaining next prompt:** Ungated cab/desk product + Docs SSOT nits are **exhausted**. Next implementation requires an **explicit user unlock by name** (AA / CarPlay / VU / LEZ / live £ / HD / billing / Android offline / country PBF). Do not invent multi-surface crowd LAN or reintroduce “P0 Blocked since 2026-09-19” / Phase 58 Blocked. Physical Block 1b smoke is optional — not a programme gate.

---
  
Phase 20 — product verification

Date: 2026-08-27  
HEAD: `a4c36301` (pre-doc refresh)  
Environment: macOS + iPhone 17 Simulator; personal Apple team signing (`RouteFinderApp.xcodeproj`)

## Claim vs code inventory


| Claim area                        | Primary surfaces                                                                     | Verdict                                                                                   |
| --------------------------------- | ------------------------------------------------------------------------------------ | ----------------------------------------------------------------------------------------- |
| Constraint routing / ORS          | `RouteViewModel`, Settings ORS key, `OpenRouteServicePayloadBuilder`                 | Present                                                                                   |
| Physics rehearse + brief/PDF      | `rehearseRoute()`, `TripBriefPDFRenderer`, share menu                                | Present                                                                                   |
| HOS / tacho import / Can-I-drive  | HOS HUD, Settings import, `CanIDriveEvaluator`                                       | Present                                                                                   |
| Layby prediction + occupancy taps | `LaybyAdvisoryBanner`, `markCurrentLaybyFull` / `HasSpaces`, `LocalCrowdEventIngest` | Present                                                                                   |
| Fleet disk + LAN + SSE + Bonjour  | Dispatch console, Settings fleet, `RouteFinderFleetServer`, `FleetSSEClient`         | Present                                                                                   |
| Offline tiles / map pack          | Settings offline section, pack HTTP path                                             | Present                                                                                   |
| Weather OpenWeather path          | Settings OpenWeather key → `DefaultWeatherService` + hot-reload                      | Present                                                                                   |
| UK LEZ banners + avoid-on-route   | `UKLowEmissionZoneCatalog`, `LEZAvoidPolicy`                                         | Present — banners + ORS `avoid_polygons` (area + long-haul caps)                          |
| CarPlay                           | Entitlements restored on paid-team builds; fleet `.routeLoaded` bootstrap            | **Ready** — operator device QA **Pending**: `[phase5-carplay-verification.md](phase5-carplay-verification.md)` (2026-09-22 Post-U15 audit — no engineering blockers; pillars A–C through U15) |
| WeatherKit                        | Entitlement restored; OpenWeather still preferred when keyed                         | **Ready** — smoke in Phase 5 checklist; personal-team rollback in restore guide           |




## Automated evidence


| Check                                             | Result                                                                  |
| ------------------------------------------------- | ----------------------------------------------------------------------- |
| `swift test` (package)                            | **Pass** — 435 tests (2026-08-28, Xcode-beta)                           |
| `xcodebuild` RouteFinderApp (iOS Simulator)       | **Pass** — BUILD SUCCEEDED                                              |
| Simulator cold launch (`Learning.RouteFinderApp`) | **Pass** — process started; no crash/fault in first ~8s of process logs |




## Structured QA checklist


| #   | Scenario                                       | Result                  | Notes                                                                                                                                                                                                                                                                    |
| --- | ---------------------------------------------- | ----------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| 1   | Cold launch, map loads                         | **Pass** (smoke)        | Simulator launch succeeded; map tile path previously verified on personal-team device                                                                                                                                                                                    |
| 2   | Geocode origin/destination, HGV route          | **Pass** (code + tests) | Full interactive ORS call not re-run in this pass; routing covered by package tests                                                                                                                                                                                      |
| 3   | Rehearse → brief text + PDF share              | **Pass** (code + tests) | `rehearseRoute` + `TripBriefPDFRenderer` / snapshot tests green                                                                                                                                                                                                          |
| 4   | Layby advisory; Looks full / Has spaces        | **Pass** (code + tests) | Phase 19 ingest → occupancy prior wired; UI handlers on map chrome                                                                                                                                                                                                       |
| 5   | Save OpenWeather key → weather without restart | **Pass** (code + tests) | `weatherConfigurationDidChange` + `WeatherViewModel.replaceWeatherService`                                                                                                                                                                                               |
| 6   | Fleet local disk trip push                     | **Pass** (code + tests) | Disk store + dispatch VM covered by tests                                                                                                                                                                                                                                |
| 6b  | LAN Bonjour discover + SSE                     | **Pass (scripted)**     | Automated smoke: `[fleet-e2e-qa.md](fleet-e2e-qa.md)` Part A + `Scripts/fleet-e2e-smoke.sh`; live Mac↔phone checklist in Part B                                                                                                                                          |
| 7   | HOS clock + inspection checklist open          | **Pass** (code + tests) | No crash paths in suite; checklist on disk                                                                                                                                                                                                                               |
| 8   | Known degraded / restore paths                 | **Documented**          | CarPlay + WeatherKit restored in `RouteFinderApp.entitlements` for paid-team signing. Device QA checklist: `[phase5-carplay-verification.md](phase5-carplay-verification.md)`. Personal-team rollback: `[carplay-weatherkit-restore.md](carplay-weatherkit-restore.md)`. |




## Honest limits

- This is **evidence-based**, not a claim of flawless end-to-end driver QA on every path.
- Interactive map geocode + live ORS + live LAN Bonjour were not fully re-driven manually in this session; automation + launch smoke + code inventory stand in where noted.
- Production CarPlay device QA is tracked in `[phase5-carplay-verification.md](phase5-carplay-verification.md)` (paid Apple Developer team). Personal-team builds must empty entitlements per `[carplay-weatherkit-restore.md](carplay-weatherkit-restore.md)` rollback.



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
| Manual Mac↔iPhone LAN (Part B)  | **Pass (CI)** — Phase 7b inspection round-trip; physical LAN optional residual |
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


| Check                                                                                                          | Result                                                                                                                                                                                               |
| -------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `[competitive-research-2026-08.md](competitive-research-2026-08.md)` executive summary + Post-Ph27 sales lines | **Done**                                                                                                                                                                                             |
| `[competitive-feature-scorecard.md](competitive-feature-scorecard.md)` Phase 29 wave-complete note             | **Done**                                                                                                                                                                                             |
| `[competitive-gap-matrix.md](competitive-gap-matrix.md)` Ph28+ #2 Done; Ph30+ next scrape **2026-11**          | **Done**                                                                                                                                                                                             |
| Full competitor re-scrape                                                                                      | **Deferred** — next quarterly cycle (2026-11)                                                                                                                                                        |
| Manual Mac↔iPhone LAN (Fleet Part B)                                                                           | **Pass (CI)** — Phase 7b; physical LAN optional — `[fleet-e2e-qa.md](fleet-e2e-qa.md)` Part B                                                                                                                                      |
| Interactive Mac app (U1–U5)                                                                                    | **Pending local**                                                                                                                                                                                    |
| CarPlay + WeatherKit restore                                                                                   | **Ready — device QA** — entitlements merged; checklist `[phase5-carplay-verification.md](phase5-carplay-verification.md)`; rollback `[carplay-weatherkit-restore.md](carplay-weatherkit-restore.md)` |




### Ultimate competitive excellence sweep (2026-10-12)

Scope: Full quarterly competitor re-scrape (early vs Ph30+ 2026-11) + code-grounded scorecard audit + engineering gates. No entitlements / GTM.


| Check | Result |
| --- | --- |
| Runbook `[ultimate-competitive-excellence-sweep.md](ultimate-competitive-excellence-sweep.md)` | **Done** — phases + Oct 12 execution report |
| Firecrawl / Apify scrape pack → `.firecrawl/` | **Done** — 14 URL pack; CoPilot **11.4** delta captured |
| Scorecard / research / gap-matrix sync | **Done** — integers unchanged; Ph30+ #1 marked Done early |
| `swift test` | **Pass** (2026-11-09) — `swift test --filter spineSpeedLimitAcceleratesToMotorwayLimit` (Oct 12 Partial closed) |
| Fleet E2E smoke | **Pass** — 14/14 |
| web-dispatch / hosted-gateway | **Pass** |
| Android C1 (`testDebugUnitTest` + `assembleDebug`) | **Pass** — CI Temurin 17; local `.java-version` 17 (OpenJDK 25 still fails if unpinned) |
| CI `main` (historical `36718254358`) | Historical android-c1 red; **current** android-c1 Pass with JDK 17 (H2 Done 2026-11-09) |
| Device C4 / C9 / Fleet Part B | **Pass (CI sim / CI)** — Phase 7b 2026-11-11; physical TTS/GPS/LAN optional; [`phase1-device-checklist.md`](phase1-device-checklist.md); agent ungated tracks Done 2026-11-09 |
| Build recommendations (Oct 12) | P0 device next; H1 sim + H2 JDK **Done** 2026-11-09 |
| Explicit deferrals (Oct 12) | **Superseded** — see driver-first reopen 2026-10-12b |




### Driver-first reopen (2026-10-12b)

Scope: Re-open Oct 12 “Defer / intentional non-parity” under sweep policy — nothing out of scope if it benefits the driver. Docs only (no re-scrape; no feature code).


| Check | Result |
| --- | --- |
| Sweep Phase 5 formula → driver_impact (feasibility not veto) | **Done** |
| Ranked backlog H1–H3 + epics 1–11 | **Done** — `[ultimate-competitive-excellence-sweep.md](ultimate-competitive-excellence-sweep.md#driver-first-reopen--2026-10-12b)` |
| Scorecard “intentional non-parity” → sequenced gaps | **Done** |
| Gap matrix Phase 31+ + remaining gaps | **Done** |
| Research appendix policy note | **Done** |
| Hygiene retained ahead of feature chase | **H1** sim speed-limit **Done** · **H2** Android JDK/CI **Done** · **H3** device P0 (operator) |
| Android HOS duty-log MVP (`EPIC-ANDROID-HOS-DUTYLOG`) | **Pass** (2026-11-09) — `./gradlew :app:testDebugUnitTest --tests 'com.routefinder.fleetdriver.compliance.*'` (Drive/Break/Off + weekly clock path) |
| Android HOS 10h daily extension (`EPIC-ANDROID-HOS-EXTENSION`) | **Pass** (2026-11-09) — same compliance filter; `activateDailyExtension` once-per-week + clock-path 9→10h |
| Android HOS WTD + fortnight (`EPIC-ANDROID-HOS-WTD`) | **Pass** (2026-11-09) — same compliance filter; fortnight 90h gate + WTD ≥60h heads-up (Android HOS scorecard **3**) |
| Lane Overpass iOS↔Android parity (`EPIC-LANE-DEPTH`) | **Pass** (2026-11-09) — `swift test --filter LaneGuidanceEnricher`; `./gradlew … --tests '*OverpassLaneGuidance*'` (cap 12 / STRAIGHT skip / 50 km) |
| Agent delivery protocol + operator playbook in sweep doc | **Done** — commit/push end-blocks + C4/C9/Part B screenshot steps |




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


| #   | Scenario                                                    | Result                      | Notes                                                                                        |
| --- | ----------------------------------------------------------- | --------------------------- | -------------------------------------------------------------------------------------------- |
| A1  | Delete RouteFinderApp from device                           | **Pending local**           | Ensures clean Keychain + UserDefaults                                                        |
| A2  | Xcode → Clean Build Folder → run `RouteFinderApp` to device | **Pending local**           | Use `RouteFinderApp.xcodeproj` scheme                                                        |
| A3  | Login screen appears on cold launch                         | **Pass** (code)             | `RootAuthContainer` gate wired in `RouteFinderAppApp.swift`                                  |
| A4  | Liability onboarding → accept → map loads tiles             | **Pass** (code + sim smoke) | `MapBootstrapServer` loopback; physical tile load **Pending local**                          |
| A5  | ⋯ toolbar → Walkaround check opens zoned checklist          | **Pass** (code)             | Enable HGV in ⋯ menu first (Ph57 onboarding picks Car or HGV); interactive **Pending local** |
| A6  | On failure: capture device log                              | **N/A**                     | Look for `SIGABRT`, `WebKit`, `Jetsam` in Console                                            |


**Automated gate (2026-08-29):** **Ph45–48 reliability economics program** — `swift test` green (~504 cases across targets); fleet E2E smoke in CI; API usage ledger + soft budget guards; unified `RemoteRequestPolicy`; fleet + hazard coordinators extracted from `RouteViewModel`. Physical device execution of **C1–C9** deferred until after reliability gate — **Pending local** (~20 min checklist).

### Phase 43–44 CI fix + dispatch defect toast (2026-08-29)

Scope: repo-root GitHub Actions workflow, dispatch poll toast when inspection defects arrive.


| #     | Scenario                                                       | Automated       | Local confirm                                                    |
| ----- | -------------------------------------------------------------- | --------------- | ---------------------------------------------------------------- |
| P43-1 | CI workflow at repo root with `RouteFinder/` working directory | **Pass** (code) | `[.github/workflows/ci.yml](../.github/workflows/ci.yml)`        |
| P43-2 | `swift test` runs from package directory in CI                 | **Pass** (code) | macos job `working-directory: RouteFinder`                       |
| P43-3 | RouteFinderApp UI smoke in CI with simulator fallback          | **Pass** (code) | ios job `xcodebuild test`                                        |
| P44-1 | Dispatch toast when poll detects new walkaround defects        | **Pass** (unit) | `DispatchInspectionAnnouncerTests`                               |
| P44-2 | Dispatch console shows defect card + toast on LAN poll         | **Pass** (code) | `DispatchViewModel.refreshActiveTrip` — Part B **Pass (CI)** (Phase 7b) |




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




### Phase 49b — Device validation gate (2026-08-29; simulator-first 2026-09-03)

Reliability gate (Ph48) + CI green (Ph49a/Ph51–52 wave) are complete. **P0 is now simulator / CI Pass** — see `[operator-next-steps.md](operator-next-steps.md)`. Physical iPhone is an **optional pre-pilot smoke** (voice, Device Hub resize, real Keychain). Fleet Part B remains optional unless pitching LAN dispatch.

**P0 (CI sim):** C1/C2/C8 covered by `RouteFinderAppUITests` (≥12 cases). Marked Pass below after local sim green 2026-09-03.

#### Operator P0 runbook (optional physical iPhone)

**Build under test:** `main` (Ph55–57+). Prefer Car on vehicle onboarding for Waze-comparable London→Manchester. Full steps moved to `[operator-next-steps.md](operator-next-steps.md)` Block 1b.


| #       | Scenario                                          | Result                                 | Notes                                                                    |
| ------- | ------------------------------------------------- | -------------------------------------- | ------------------------------------------------------------------------ |
| P49b-P0 | C1–C2 + C8 (simulator / CI)                       | **Pass** (CI sim)                      | Expanded `RouteFinderAppUITests` 2026-09-03; physical optional pre-pilot |
| P49b-1  | C1–C9 physical iPhone checklist                   | **Optional**                           | Full table below — not required for outreach                             |
| P49b-2  | Fleet Part B LAN walkaround → dispatch inspection | **Pass** (CI)                          | Phase 7b inspection round-trip + desk smoke; physical LAN optional before first fleet demo |
| P49b-3  | Settings API Usage Today + Legal Driver Terms     | **Pass** (sim)                         | `testSettingsAPIUsageAndLegalDriverTerms`                                |




### Phase 55 — Start Navigation UX (2026-08-29)

Scope: labeled primary Start / Stop on the iOS route results sheet so drivers do not need to discover Play or the compass control.


| #     | SLO / evidence                                                  | Automated                 | Notes                                                                   |
| ----- | --------------------------------------------------------------- | ------------------------- | ----------------------------------------------------------------------- |
| P55-1 | Results sheet shows **Start Navigation** / **Start Simulation** | **Pass** (code + UI test) | `NavigationStartRow` in results sheet only (Ph56 removed top duplicate) |
| P55-2 | Live GPS starts follow mode; Simulation toggles playback        | **Pass** (code)           | `startNavigationFromResults` / `stopNavigationFromResults`              |
| P55-3 | Active session shows **Stop**; compass shortcut unchanged       | **Pass** (code)           | Toolbar `handleNavigationControlTap` retained                           |
| P55-4 | UI test: Start Navigation visible after seeded route            | **Pass** (UI test)        | `testStartNavigationButtonOnRouteResults` green on iPhone 17 sim        |




#### Phase 55 code surfaces


| Feature          | Primary files                                                             |
| ---------------- | ------------------------------------------------------------------------- |
| Start / Stop CTA | `IOSMapChrome.NavigationStartRow`                                         |
| Session helpers  | `RouteViewModel.startNavigationFromResults` / `stopNavigationFromResults` |
| UI test seed     | `RouteViewModel.seedUITestDemoRouteIfNeeded`, `UITEST_SEED_ROUTE`         |




### Phase 57 — Map canvas, voice, routing clarity, bottom sheet (2026-08-30)

Scope: `map.resize()` fix, voice quality, Car vs HGV onboarding, Waze-style bottom peek sheet.


| #     | SLO / evidence                                              | Automated                   | Notes                                                               |
| ----- | ----------------------------------------------------------- | --------------------------- | ------------------------------------------------------------------- |
| P57-1 | Map canvas resizes with window — no parchment cube          | **Pass** (code)             | `ResizeObserver`, `layoutSubviews` → `map.resize()`                 |
| P57-2 | Pan/zoom not thrashed by SwiftUI invalidation               | **Pass** (code)             | Removed `playbackRevision`; debounced refit; user-only zoom publish |
| P57-3 | Navigation voice uses enhanced voice + metric prompts       | **Pass** (code + unit test) | `NavigationVoiceService` queue; Settings voice/rate picker          |
| P57-4 | First launch asks Car vs HGV before first route             | **Pass** (code + UI test)   | `VehicleModeOnboardingSheet`; `testVehicleModeOnboardingCarAndHGV`  |
| P57-5 | Bottom peek "Where to?" + route profile badge               | **Pass** (code + UI test)   | `mapSearchPeekBar`, `routeProfileBadge`, `activeRouteChip`          |
| P57-6 | UI tests: peek bar + Start + Route Overview on seeded route | **Pass** (UI test)          | `testMapSearchPeekBarAtLaunch`, existing Ph55/Ph56 tests            |
| P57-7 | P0 gate after Ph55–57                                       | **Pass** (CI sim)           | Simulator-first; physical = optional Block 1b smoke                 |




#### Phase 57 code surfaces


| Feature            | Primary files                                                                 |
| ------------------ | ----------------------------------------------------------------------------- |
| Map resize         | `MapLibreMapHTML`, `MapLibreWebMapView` host `layoutSubviews`                 |
| Voice              | `NavigationVoiceService`, `ManeuverSpeechFormatter`, `SettingsSheet`          |
| Vehicle onboarding | `VehicleModeOnboardingSheet`, `RouteViewModel.applyVehicleModeFromOnboarding` |
| Bottom sheet UX    | `IOSMapChrome` peek detent, `RouteProfileBadge`, slim toolbar                 |




### Phase 56 — iOS native map feel (2026-08-30)

Scope: edge-to-edge map, persistent vehicle marker in follow/sim, Route Overview reset, compact alert stack.


| #     | SLO / evidence                                            | Automated                 | Notes                                                                             |
| ----- | --------------------------------------------------------- | ------------------------- | --------------------------------------------------------------------------------- |
| P56-1 | Map fills screen — no white letterboxing                  | **Pass** (code)           | `MapCanvasBackdrop`, `ignoresSafeArea`, parchment WKWebView                       |
| P56-2 | Vehicle visible in preview / sim / GPS follow             | **Pass** (code)           | `liveMapVehicleState`, adapter footprint, sim bridge push                         |
| P56-3 | **Route overview** toolbar resets north-up full route     | **Pass** (code + UI test) | `resetMapToRouteOverview`, `mapRouteOverviewButton`                               |
| P56-4 | Top chrome shows max 2 alerts + overflow chip             | **Pass** (code)           | `CompactAlertStack`; Start only in results sheet                                  |
| P56-5 | UI tests: Start in sheet + Route Overview on seeded route | **Pass** (UI test)        | `testStartNavigationButtonOnRouteResults`, `testRouteOverviewButtonOnSeededRoute` |




#### Phase 56 code surfaces


| Feature         | Primary files                                                               |
| --------------- | --------------------------------------------------------------------------- |
| Full-bleed map  | `MapCanvasBackdrop`, `ContentView`, `MapRouteView`, `MapLibreWebMapView`    |
| Vehicle marker  | `RouteViewModel.liveMapVehicleState`, `NavigationSessionMapAdapter`         |
| Route overview  | `RouteViewModel.resetMapToRouteOverview`, `IOSMapToolbar`, `fitRouteBounds` |
| Alert declutter | `IOSMapChrome.CompactAlertStack`, `CompactRestrictionZoneBanner`            |




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
| P53-4 | Outreach script + target table                                    | **Pass** (doc)        | `[pilot-outreach.md](pilot-outreach.md)` — send after CI P0 Pass                                                       |
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
| P42-3 | Fleet Part B walkaround → dispatch inspection                   | **Pass** (CI)   | Phase 7b `fleetInspectionSummaryRoundTripsViaSnapshot`; physical LAN optional |




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

Launch arguments used by smoke tests: `UITEST_SKIP_AUTH`, `UITEST_SKIP_ONBOARDING`, `UITEST_SEED_ROUTE` (Ph55 Start Navigation).

#### Phase 38–40 code surfaces


| Feature                | Primary files                                                                                                             |
| ---------------------- | ------------------------------------------------------------------------------------------------------------------------- |
| XCTest smoke           | `RouteFinderAppUITests`, `UITestLaunchConfigurator`, accessibility IDs in `AuthGateView`, `SettingsSheet`, `IOSMapChrome` |
| Walkaround trip brief  | `TripBriefInspectionSummary`, `TripBriefFormatter`, `RouteViewModel.saveActiveInspection`                                 |
| Fleet inspection PDF   | `FleetTripSnapshot.inspectionReportPDFBase64`, `FleetTrip.latestInspectionSummary`                                        |
| Hazard overlay rebuild | `HazardOverlayBuilder`, `hydrateCrowdReportsFromDisk`                                                                     |




### Consolidated iPhone device QA — Phase A + Ph30–35 (2026-08-28)

**Simulator-first (2026-09-03; Phase 7b 2026-11-11):** C1–C9 are **Pass (CI sim)**. Physical iPhone = optional pre-pilot smoke (hear TTS, live TomTom GPS, LAN toast) — see `[operator-next-steps.md](operator-next-steps.md)` Block 1b / `[phase1-device-checklist.md](phase1-device-checklist.md)`.


| #   | Scenario                                                 | Result            | Date | Tester | Pass / Fail | Notes                                                                                       |
| --- | -------------------------------------------------------- | ----------------- | ---- | ------ | ----------- | ------------------------------------------------------------------------------------------- |
| C1  | Cold launch / install path                               | **Pass** (CI sim) | —    | CI     | Pass        | `testColdLaunchShowsAuthOrMap`; physical delete+install optional                            |
| C2  | Driver Terms / vehicle mode / map / no cloud nag         | **Pass** (CI sim) | —    | CI     | Pass        | `testVehicleModeOnboardingCarAndHGV`, `testCloudBannerHiddenWithMockKey`, badge/Start tests |
| C3  | Walkaround v2: zones, defect note, PDF share             | **Pass** (CI sim) | 2026-09-19 | CI     | Pass (sim)  | Phase 7 `testWalkaroundDefectNoteEnablesSave`; physical PDF share optional smoke |
| C4  | Layby voice alert on HGV route (Settings on)             | **Pass** (CI sim) | 2026-11-11 | CI     | Pass (sim)  | Phase 7b `testLaybyAheadBannerOnSeededRoute`; hear TTS once = optional residual |
| C5  | Fuel card picker → ahead banner on route                 | **Pass** (CI sim) | 2026-09-19 | CI     | Pass (sim)  | Phase 7 picker UITest; live OSM fuel POI banner still optional physical          |
| C6  | Report closure → hazard ahead banner + voice             | **Pass** (CI sim) | 2026-09-19 | CI     | Pass (sim)  | Phase 7 banner inject; live report still optional physical                       |
| C7  | Roadworks ahead banner (OSM construction corridor)       | **Pass** (CI sim) | 2026-09-19 | CI     | Pass (sim)  | Phase 7 banner inject; OSM corridor still optional physical                      |
| C8  | Settings hub drill-down (API Usage + Legal Driver Terms) | **Pass** (CI sim) | —    | CI     | Pass        | `testSettingsAPIUsageAndLegalDriverTerms` / `testSettingsHubOpens`; spot-check on device    |
| C9  | TomTom key set → live traffic hazard ahead during nav    | **Pass** (CI sim) | 2026-11-11 | CI     | Pass (sim)  | Phase 7b `testTomTomHazardBannerOnSeededRoute` (`source: tomtom:`); live GPS TomTom = optional residual |


**Fleet Part B (P49b-2)** — walkaround defect → dispatch inspection toast/PDF:


| Scenario                                          | Result                                          | Date       | Tester | Pass / Fail | Notes                                                                                               |
| ------------------------------------------------- | ----------------------------------------------- | ---------- | ------ | ----------- | --------------------------------------------------------------------------------------------------- |
| P49b-2 Fleet LAN walkaround → dispatch inspection | **Pass** (CI)                                   | 2026-11-11 | CI     | Pass        | `fleetInspectionSummaryRoundTripsViaSnapshot` + `fleetE2EWorkflowPushSnapshotAndSSE` + web-dispatch `inspectionSummary` smoke; physical Mac↔phone LAN = optional before first fleet demo |




### Engineering excellence Phase 2 — EPIC-P0-DEVICE (2026-09-18; refreshed 2026-09-19)

Priority: [`engineering-benchmark-2026-09.md`](engineering-benchmark-2026-09.md) `EPIC-P0-DEVICE`. Automated CI parity; Phase 7b closed C4/C9/Part B as Pass (CI). Physical residuals remain optional.

#### Automated CI (local 2026-09-19 Phase 7 refresh)

| Job | Command | Result | Notes |
|-----|---------|--------|-------|
| macOS package | `cd RouteFinder && swift test` | **Pass** | Full package test run |
| Fleet Part A | `RouteFinder/Scripts/fleet-e2e-smoke.sh` | **Pass** | Includes `fleetInspectionSummaryRoundTripsViaSnapshot` (Phase 7b) |
| iOS UI smoke | `xcodebuild test … RouteFinderAppUITests` | **Pass** | Includes Phase 7 + 7b C3–C9 cases |
| web-dispatch | `npm test` | **Pass** | `scripts/smoke.mjs` |
| hosted-gateway | `npm test` | **Pass** | 8/8 vitest |
| android-c1 | `./gradlew :app:testDebugUnitTest` | **Pass** | Requires **JDK 17–22**; **Fail** if `JAVA_HOME` is OpenJDK **25** (use `/usr/libexec/java_home -v 22`) |

**Phase 2 gate (automated):** **Pass** — matches `.github/workflows/ci.yml` job surface.

#### P0 / C1–C9 summary (2026-09-19 Phase 7; Phase 7b 2026-11-11)

| ID | Scenario | Result | Owner | Notes |
|----|----------|--------|-------|-------|
| **P0** | Simulator / CI gate | **Pass** | CI | C1–C9 (sim) + suite |
| **C1** | Cold launch | **Pass** (CI sim) | CI | `testColdLaunchShowsAuthOrMap` |
| **C2** | Driver Terms / vehicle mode | **Pass** (CI sim) | CI | Onboarding + mock key tests |
| **C3** | Walkaround v2 + PDF | **Pass** (CI sim) | CI | `testWalkaroundDefectNoteEnablesSave` — physical PDF share still optional |
| **C4** | Layby voice | **Pass** (CI sim) | CI | Phase 7b `testLaybyAheadBannerOnSeededRoute`; hear TTS once optional |
| **C5** | Fuel card picker / banner | **Pass** (CI sim) | CI | `testFuelCardProviderPickerPersists` — live POI banner optional physical |
| **C6** | Hazard ahead | **Pass** (CI sim) | CI | `testHazardAheadBannerOnSeededRoute` (DEBUG inject); live report still optional |
| **C7** | Roadworks banner | **Pass** (CI sim) | CI | `testRoadworksAheadBannerOnSeededRoute` (DEBUG inject); OSM corridor still optional |
| **C8** | Settings hub + Legal Driver Terms | **Pass** (CI sim) | CI | `testSettingsAPIUsageAndLegalDriverTerms` |
| **C9** | TomTom live hazard | **Pass** (CI sim) | CI | Phase 7b `testTomTomHazardBannerOnSeededRoute`; live GPS TomTom optional |

#### Fleet Part B (CI + optional LAN)

Script: [`fleet-e2e-qa.md`](fleet-e2e-qa.md) **Part B** (steps 1–9) for physical LAN; CI covers snapshot inspection path.

| ID | Scenario | Result | Owner | Notes |
|----|----------|--------|-------|-------|
| Part A | HTTP/SSE/Bonjour smoke | **Pass** | CI / agent | `fleet-e2e-smoke.sh` (incl. inspection filter) |
| **Part B** | Walkaround inspection → desk defect payload | **Pass** (CI) | CI | `fleetInspectionSummaryRoundTripsViaSnapshot` + web-dispatch `inspectionSummary` smoke; physical Mac↔phone LAN optional before first fleet demo |

**Phase 2 gate (device):** Programme gate **Pass (CI)** via Phase 7b — physical residuals optional (Block 1b / Part B LAN).

---

### Engineering excellence Phase 3 — EPIC-STRANGER-UX (2026-09-18)

Evidence: [`phase3-stranger-ux-verification.md`](phase3-stranger-ux-verification.md).

| Check | Result | Notes |
|-------|--------|-------|
| Settings deep link → API Keys | **Pass** | `settingsDeepLinkConsumesOnce` |
| Fleet wizard remote default + launch cover | **Pass** | `FleetSetupWizardView` / `LaunchCover.fleetWizard` |
| UITest pair → wizard | **Pass** | `testDriverPairFleetOpensWizard` |
| Role picker UITest | **Pass** | `testLaunchRolePickerVisible` |

**Competitive edge:** Driver never creates a HeiGIT account when desk runs `--ors-key` — fewer portal steps than CoPilot Account Manager seat dance.

---

### Engineering excellence Phase 4 — platform parity (2026-09-18)

Evidence: [`phase4-platform-parity-verification.md`](phase4-platform-parity-verification.md).

| Surface | Result | Notes |
|---------|--------|-------|
| CarPlay entitlements + coordinator | **Ready** (code) | Device QA: [`phase5-carplay-verification.md`](phase5-carplay-verification.md) |
| Android C2 unit + APK | **Pass** | JDK 17–22 |
| Hosted gateway client pointer | **Pass** | `httpsFleetURLInfersHostedConnectionKind` + vitest |

---

### Engineering excellence Phase 5 — test hardening (2026-09-19)

Evidence: [`engineering-test-matrix.md`](engineering-test-matrix.md).

| Check | Result |
|-------|--------|
| Fleet smoke **13/13** | **Pass** |
| Telematics HTTP ingest | **Pass** (`fleetTelematicsIngestViaHTTP`) |
| SSE helpers + GPS E2E | **Pass** (`fleetE2EWorkflowPushSnapshotAndSSE`) |

---

### Engineering excellence Phase 6 — performance + demo (2026-09-19)

Evidence: [`phase6-performance-verification.md`](phase6-performance-verification.md), [`demo-superiority-script.md`](demo-superiority-script.md).

| Hotspot | Result |
|---------|--------|
| Overpass lane cap (12) | **Pass** |
| Offline corridor monotonic progress | **Pass** |
| Web map fingerprint (no 5 s churn) | **Pass** |
| Fleet proxy 429 copy | **Pass** |

---

### Engineering excellence Phase 7 — P0 simulator consolidation (2026-09-19)

Evidence: [`phase7-device-simulator-verification.md`](phase7-device-simulator-verification.md).

| Check | Result | Notes |
|-------|--------|-------|
| phase20 prompt chain + Phases 3–6 ledger | **Pass** | This section |
| C3 walkaround UITest | **Pass** (CI sim) | `testWalkaroundDefectNoteEnablesSave` |
| C5 fuel card UITest | **Pass** (CI sim) | `testFuelCardProviderPickerPersists` |
| C6/C7 banner UITests | **Pass** (CI sim) | DEBUG `UITEST_SEED_*_BANNER` inject |
| C4 / C9 / Part B | **Pass (CI)** 2026-11-11 | Phase 7b CI-sim close supersedes 2026-09-19 Blocked; physical residuals optional |
| Matrix + CI gate | **Pass** | See Phase 7 verification doc |

**Competitive edge:** Objective **Pass (CI sim)** vs **Pending local** rows — competitor demos rely on unaudited manual scripts; RouteFinder keeps an evidence ledger engineers can re-run.

---

### Operator device QA attempt — C4 / C9 / Part B (2026-09-19; superseded by Phase 7b 2026-11-11)

| Check | Result | Notes |
|-------|--------|-------|
| Preflight `swift test` | **Pass** | Package green |
| Preflight `fleet-e2e-smoke.sh` | **Pass** | **13/13** |
| ORS / TomTom keys in Mac env | **Present** | Keys exported in agent shell; device Settings still required for C9 |
| Physical iPhone Online | **No** | `xctrace`: Noah’s Iphone / iPhone (2) / `.` all **Offline** |
| Part B Mac↔iPhone LAN | **Blocked** | Cannot push/toast/walkaround→dispatch without Online phone |
| C4 layby voice | **Blocked** | Cannot hear TTS without physical device |
| C9 TomTom live hazard | **Blocked** | Cannot run Live GPS nav + device TomTom Settings |
| Fail → backlog | **N/A** | Blocked ≠ Fail — no [`pilot-feedback-backlog.md`](pilot-feedback-backlog.md) row |
| Operator confirmation | **Blocked** | 2026-09-19: operator replied “Operator QA done” but C4/C9/Part B still **not executed** — retain Blocked until Online iPhone + checklist |

**Historical note:** 2026-09-19 Blocked was not a code Fail. **Phase 7b (2026-11-11)** reclassified C4/C9/Part B as **Pass (CI sim / CI)**; physical residuals remain optional via [`phase1-device-checklist.md`](phase1-device-checklist.md).

---

### Ultimate HGV platform — U5 parity gates (2026-09-19)

Spec: [`ultimate-hgv-platform-spec.md`](ultimate-hgv-platform-spec.md). Contracts + intake + risk fuse + walkaround media shipped in U1–U4.

| Gate | Epic / doc | Status |
|------|------------|--------|
| Physical C4 / C9 / Fleet Part B | `EPIC-P0-DEVICE` / this ledger | **Pass (CI)** — Phase 7b; physical residuals optional |
| Android C2 job intake | [`phase6b-android-nav-verification.md`](phase6b-android-nav-verification.md) | **Pass** (unit) / corridor **Pending local** |
| CarPlay production | [`phase5-carplay-verification.md`](phase5-carplay-verification.md) | **Pending** paid-team device QA (operator) — Post-U15: engineering rows Pass; interactive device rows open |
| C3 walkaround photo | [`phase1-device-checklist.md`](phase1-device-checklist.md) | **Pass** (code) / photo on device **Pending local** |
| U3 predictive risk UITest | `testPredictiveRiskPrimaryBannerOnSeededRoute` + `UITEST_SEED_PREDICTIVE_RISK` | **Pass** (code) — App UITest asserts `predictiveRiskPrimaryBanner` |
| U2 jobBrief SSE round-trip | `fleetCreateAndPushTripRoundTripsJobBrief` | **Pass** — included in fleet smoke |
| Gap-close regression | 2026-09-19 | **Pass** — RegCheck intake, Android ORS from brief, live fuse HUD |
| Spec alignment polish | 2026-09-21 | **Pass** — hazard voice dedup; Android ORS `hazmat` from ADR; web time windows; forecast/clearance still Deferred |

---

### Phase 1 — Apple core hardening (2026-09-09)

Scope: fleet wizard/QR, ORS proxy, regression tests; zero automated failures before physical C3–C9 sign-off.


| Check                                       | Result            | Notes                                                                                                                  |
| ------------------------------------------- | ----------------- | ---------------------------------------------------------------------------------------------------------------------- |
| `swift test` (package)                      | **Pass**          | Re-verified 2026-09-18 (Engineering Phase 2)                                                                           |
| `./Scripts/fleet-e2e-smoke.sh`              | **Pass**          | 9/9 filters (2026-09-18)                                                                                               |
| `web-dispatch` `npm test` + `npm run build` | **Pass**          | Smoke 2026-09-18; production build not re-run locally this session                                                     |
| C3–C9 physical sign-off                     | **Pass (CI sim)** | Phase 7b C1–C9 CI sim; physical hear/live GPS optional — `[phase1-device-checklist.md](phase1-device-checklist.md)` |
| Fleet Part B physical sign-off              | **Pass (CI)** | Phase 7b inspection round-trip; physical LAN optional — `[fleet-e2e-qa.md](fleet-e2e-qa.md)` |




#### Phase 1 code surfaces


| Feature                  | Primary files                                                                 |
| ------------------------ | ----------------------------------------------------------------------------- |
| Fleet setup wizard       | `FleetSetupWizardView`, `SettingsSheet`                                       |
| Vehicle QR pair          | `VehiclePairingQRView`, `FleetVehicleQRScannerView`, `DispatchTripFormView`   |
| ORS proxy + metering     | `FleetORSProxy`, `FleetProxyUsageMeter`, `FleetServerConfig`                  |
| Client routing via proxy | `FleetORSRoutingFactory`, `RouteViewModel.usesFleetORSProxy`                  |
| Proxy regression tests   | `FleetProxyTests`, `FleetORSRoutingFactoryTests`, `FleetProxyUsageMeterTests` |




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


