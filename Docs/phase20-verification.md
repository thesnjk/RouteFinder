# Phase 20 — product verification

Date: 2026-08-27  
HEAD: `a4c36301` (pre-doc refresh)  
Environment: macOS + iPhone 17 Simulator; personal Apple team signing (`RouteFinderApp.xcodeproj`)

## Claim vs code inventory

| Claim area | Primary surfaces | Verdict |
|---|---|---|
| Constraint routing / ORS | `RouteViewModel`, Settings ORS key, `OpenRouteServicePayloadBuilder` | Present |
| Physics rehearse + brief/PDF | `rehearseRoute()`, `TripBriefPDFRenderer`, share menu | Present |
| HOS / tacho import / Can-I-drive | HOS HUD, Settings import, `CanIDriveEvaluator` | Present |
| Layby prediction + occupancy taps | `LaybyAdvisoryBanner`, `markCurrentLaybyFull` / `HasSpaces`, `LocalCrowdEventIngest` | Present |
| Fleet disk + LAN + SSE + Bonjour | Dispatch console, Settings fleet, `RouteFinderFleetServer`, `FleetSSEClient` | Present |
| Offline tiles / map pack | Settings offline section, pack HTTP path | Present |
| Weather OpenWeather path | Settings OpenWeather key → `DefaultWeatherService` + hot-reload | Present |
| UK LEZ banners + avoid-on-route | `UKLowEmissionZoneCatalog`, `LEZAvoidPolicy` | Present — banners + ORS `avoid_polygons` (area + long-haul caps) |
| CarPlay | Code present; entitlements emptied for personal team | **Degraded** — not device-QA’d on personal team |
| WeatherKit | Fallback when no OpenWeather key | **Degraded** on personal team (no entitlement) |

## Automated evidence

| Check | Result |
|---|---|
| `swift test` (package) | **Pass** — 435 tests (2026-08-28, Xcode-beta) |
| `xcodebuild` RouteFinderApp (iOS Simulator) | **Pass** — BUILD SUCCEEDED |
| Simulator cold launch (`Learning.RouteFinderApp`) | **Pass** — process started; no crash/fault in first ~8s of process logs |

## Structured QA checklist

| # | Scenario | Result | Notes |
|---|---|---|---|
| 1 | Cold launch, map loads | **Pass** (smoke) | Simulator launch succeeded; map tile path previously verified on personal-team device |
| 2 | Geocode origin/destination, HGV route | **Pass** (code + tests) | Full interactive ORS call not re-run in this pass; routing covered by package tests |
| 3 | Rehearse → brief text + PDF share | **Pass** (code + tests) | `rehearseRoute` + `TripBriefPDFRenderer` / snapshot tests green |
| 4 | Layby advisory; Looks full / Has spaces | **Pass** (code + tests) | Phase 19 ingest → occupancy prior wired; UI handlers on map chrome |
| 5 | Save OpenWeather key → weather without restart | **Pass** (code + tests) | `weatherConfigurationDidChange` + `WeatherViewModel.replaceWeatherService` |
| 6 | Fleet local disk trip push | **Pass** (code + tests) | Disk store + dispatch VM covered by tests |
| 6b | LAN Bonjour discover + SSE | **Pass (scripted)** | Automated smoke: [`fleet-e2e-qa.md`](fleet-e2e-qa.md) Part A + `Scripts/fleet-e2e-smoke.sh`; live Mac↔phone checklist in Part B |
| 7 | HOS clock + inspection checklist open | **Pass** (code + tests) | No crash paths in suite; checklist on disk |
| 8 | Known degraded paths | **Documented** | CarPlay inactive (personal team entitlements); WeatherKit unavailable without paid team / OpenWeather key. Restore guide: [`carplay-weatherkit-restore.md`](carplay-weatherkit-restore.md) |

## Honest limits

- This is **evidence-based**, not a claim of flawless end-to-end driver QA on every path.
- Interactive map geocode + live ORS + live LAN Bonjour were not fully re-driven manually in this session; automation + launch smoke + code inventory stand in where noted.
- Do not claim production CarPlay QA on personal-team builds.

## Post-fix verification (2026-08-28)

HEAD: `8e70df66`  
Environment: macOS; `DEVELOPER_DIR=/Library/Developer/CommandLineTools` (full Xcode.app not installed — `xcodebuild` unavailable; packaged app used instead).

### Automated re-run

| Check | Result | Notes |
|---|---|---|
| `swift test` (package) | **Pass** — 409 tests | Full suite green |
| Fix-specific unit tests (Keychain, geocode heuristic, LEZ long-haul cap, sim camera/zoom, curve governor) | **Pass** — 13 targeted tests | Filters on `KeychainStoreTests`, `OpenRouteServiceGeocoderTests`, `TruckPoiLivingLayerTests`, `MapViewControllerBridgeTests`, `CurveSpeedAdvisorTests` |
| `Scripts/package-macos-app.sh` | **Pass** | Hardened codesign (`--options runtime`, inner-then-bundle, requires dev cert); `TeamIdentifier=GHBHLM9UAX`, `Runtime Version` present |
| `xcodebuild` RouteFinderMac | **Skipped** | Full Xcode.app not installed in agent environment; use locally after `sudo xcode-select -s /Applications/Xcode.app/Contents/Developer` |

### Recent-fix smoke checklist

| # | Scenario | Result | Notes |
|---|---|---|---|
| K1 | RouteFinderMac Keychain — no re-prompt | **Pass** | ORS key present in data-protection vault (`com.routefinder.vault.*`); consecutive Keychain reads return same credential; packaged app has `keychain-access-groups`. GUI relaunch not exercised in agent session — confirm locally with **RouteFinderMac** scheme. |
| G1 | `33 sørnesvegen` → Norway | **Pass** | Correct Ålesund address (prior QA used typo `sameswegen`, which is not a real place). Live Pelias global search returns Norway; overseas heuristic matches `vegen` after ø→o normalization. |
| R1 | Long haul + LEZ avoid — no 2004 | **Pass** | `lezAvoidPolicyOmitsPolygonsOnLongHaul` (Norwich → Ålesund); live ORS HGV route Norwich → Edinburgh (611 km) succeeds with no avoid polygons on long haul. |
| S1 | 30 mph sim feel + centered camera | **Pass** (automated) | `defaultTrackingZoom_isPulledBackForHGVFeel` (15.0), `cameraFollowCenter_offsetsForwardHalfLength`, `maxUpcomingCurveSpeedMps_nearStraightDensifiedSpineAllowsResidentialCruise`. Visual 30 mph feel / turn pivot: confirm via **RouteFinderMac** Xcode scheme. |

### Honest limits (post-fix pass)

- **RouteFinderMac launch:** packaged `RouteFinder.app` from older `package-macos-app.sh` builds could crash with `Taskgated Invalid Signature` on macOS 26 (missing hardened runtime). Use Xcode **RouteFinderMac** scheme, or rebuild with the hardened package script.
- Visual sim feel (S1) and Keychain dialog absence (K1 relaunch) require local **RouteFinderMac** confirmation in Xcode.

### Sim UX + lane guidance (2026-08-28)

| # | Scenario | Automated | Local confirm |
|---|---|---|---|
| U1 | Session auto-unlock / pre-filled email | `SessionWorkspaceSettings` + `SessionController.bootstrap()` Touch ID path | Relaunch twice — Touch ID or pre-filled login |
| U2 | Vehicle workspace restore | `VehicleWorkspaceSettings` round-trip + `restoreVehicleWorkspace()` + persist on all sidebar/settings/control-sheet edits | Quit → relaunch — reg/dims/HGV mode persist |
| U3 | 30 mph cruise (traffic off) | `applyTrafficToSimulation` default false; physics uses posted limit only | Sim on 30 mph leg — dial ~30, not 24 |
| U4 | Center-anchored HGV polygon | `renderMode` forces polygon while tracking; cab/trailer `footprintParts` | Turn at zoom 15 — body pivots from center |
| U5 | Lane banner | `TurnLanesParserTests`, `LaneGuidanceEnricher`, `LaneGuidanceBanner` on map chrome | Approach maneuver — lane strip on map top |

`swift test`: **417+ tests** green (includes workspace settings round-trip, lane parser, footprint, and enricher cap/cache tests).

### Lane guidance hardening (2026-08-28)

| Check | Result | Notes |
|---|---|---|
| Route find latency | **Pass** (design) | Heuristics applied synchronously; Overpass capped to 8 maneuvers / 50 km in background |
| Offline route parity | **Pass** (code) | Offline tiled routes use heuristic lane guidance only (`queryOverpass: false`); online routes use capped async Overpass enrichment |
| Overpass cache | **Pass** (unit) | `OverpassLaneGuidanceCache` + `LaneGuidanceEnricherTests` |
| U1–U5 interactive | **Pending local** | Run **RouteFinderMac** in Xcode — automated coverage only in cloud agent |

## Critical bugs found

None blocking. No Phase 20 hotfix required.

## Phase 26 live QA (2026-08-28)

Market research push + wave 1 features (Break Now, LEZ v2, lane voice). **No CarPlay / WeatherKit.**

| # | Scenario | Persona | Result | Notes |
|---|---|---|---|---|
| D1 | Norwich → Edinburgh HGV route + Rehearse | Owner-op | **Pass** (code + tests) | Physics ETA + brief export paths covered by existing suite |
| D2 | Traffic reroute banner | Owner-op | **Pass** (code + tests) | Standstill + alternate logic in `RouteViewModel` |
| D3 | Break Now → layby rank | Owner-op | **Pass** (unit) | `predictBreakNow` + HUD `cup.and.saucer.fill` button; map centers via `focusMapOnLayby` |
| D4 | Lane banner + voice at junction | Owner-op | **Pass** (unit) | `spokenLanePhrase` + prepare-tier prompt tests |
| D5 | LEZ cross (London hop) | Owner-op | **Pass** (unit) | 11 zones; Euro-class copy in `announcementMessage`; long-haul avoid cap unchanged |
| D6 | Mac dispatch push → iPhone SSE | Small fleet | **Pass** (code + tests) | SSE hub + toast wired; live Mac↔phone not re-run this session |
| D7 | Bonjour discover fleet server | Small fleet | **Pass (scripted)** | [`fleet-e2e-qa.md`](fleet-e2e-qa.md) Part A automated + Part B manual checklist |
| D8 | `swift test` full suite | Engineering | **Pass** | 435 tests green with Xcode-beta `DEVELOPER_DIR` |

### Phase 26 code surfaces

| Feature | Primary files |
|---|---|
| Break Now | `LaybyPredictionEngine.predictBreakNow`, `RouteViewModel.findBreakNow`, `IOSMapChrome` / `MapFirstShell` HUD |
| LEZ v2 | `UKLowEmissionZoneCatalog` (+5 zones), `announcementMessage` Euro copy, Settings explainer |
| Lane voice | `ManeuverSpeechFormatter.spokenLanePhrase`, prepare/execute tiers |

### Automated evidence (Phase 26)

| Check | Result |
|---|---|
| `LaybyOccupancyReportTests` Break Now + lane voice | **Pass** |
| `TruckPoiLivingLayerTests` LEZ catalog expansion | **Pass** |
| Full `swift test` | **Pass** (see D8) |

### Honest limits (Phase 26)

- Interactive Break Now tap-to-map-center not re-run on device this session; unit + code inventory stand in.
- TRAVIS parking booking intentionally not implemented — documented in research docs.
- CarPlay and WeatherKit remain out of scope.

### Phase 27c fleet E2E QA (2026-08-28)

HEAD: `315d39e9`  
Deliverables: [`Docs/fleet-e2e-qa.md`](fleet-e2e-qa.md), [`RouteFinder/Scripts/fleet-e2e-smoke.sh`](../RouteFinder/Scripts/fleet-e2e-smoke.sh), consolidated test `fleetE2EWorkflowPushSnapshotAndSSE`.

| Check | Result |
|---|---|
| `./Scripts/fleet-e2e-smoke.sh` | **Pass** — HTTP push, SSE, Bonjour helpers, E2E workflow (9/9 filters) |
| Manual Mac↔iPhone LAN (Part B) | **Pending local** — checklist documented; run when two devices available |
| Demo dispatch fallback (Part C) | **Documented** — single-device path via Settings |

### Phase 28 ship hygiene (2026-08-28)

HEAD: `c9355a54`  
Scope: scorecard + verification doc refresh; CarPlay/WeatherKit restore **playbook only** (no entitlement merge on personal team).

| Check | Result |
|---|---|
| Scorecard Ph27 gaps marked Done | **Done** |
| [`carplay-weatherkit-restore.md`](carplay-weatherkit-restore.md) playbook | **Done** — execute only on paid Apple Developer Program team |
| Full `swift test` | **Pass** — 435 tests (Xcode-beta) |

### Phase 29 competitive positioning refresh (2026-08-28)

HEAD: `cb3f107`  
Scope: light positioning refresh — no code, entitlements, or Firecrawl re-scrape.

| Check | Result |
|---|---|
| [`competitive-research-2026-08.md`](competitive-research-2026-08.md) executive summary + Post-Ph27 sales lines | **Done** |
| [`competitive-feature-scorecard.md`](competitive-feature-scorecard.md) Phase 29 wave-complete note | **Done** |
| [`competitive-gap-matrix.md`](competitive-gap-matrix.md) Ph28+ #2 Done; Ph30+ next scrape **2026-11** | **Done** |
| Full competitor re-scrape | **Deferred** — next quarterly cycle (2026-11) |
| Manual Mac↔iPhone LAN (Fleet Part B) | **Pending local** — [`fleet-e2e-qa.md`](fleet-e2e-qa.md) Part B |
| Interactive Mac app (U1–U5) | **Pending local** |
| CarPlay + WeatherKit restore | **Blocked — paid team** — [`carplay-weatherkit-restore.md`](carplay-weatherkit-restore.md) |
