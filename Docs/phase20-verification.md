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
| `swift test` (package) | **Pass** — 409 tests (2026-08-28 re-run) |
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
| 6b | LAN Bonjour discover + SSE | **Partial** | Server/SSE unit tests pass; live Mac↔phone discover not exercised this session |
| 7 | HOS clock + inspection checklist open | **Pass** (code + tests) | No crash paths in suite; checklist on disk |
| 8 | Known degraded paths | **Documented** | CarPlay inactive (personal team entitlements); WeatherKit unavailable without paid team / OpenWeather key |

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
| `Scripts/package-macos-app.sh` | **Pass** | `RouteFinder.app` codesigned; `keychain-access-groups` = `GHBHLM9UAX.com.routefinder.macos` |
| `xcodebuild` RouteFinderMac | **Skipped** | Requires full Xcode.app (not installed; `xcode-select` points to missing `/Applications/Xcode.app`) |

### Recent-fix smoke checklist

| # | Scenario | Result | Notes |
|---|---|---|---|
| K1 | RouteFinderMac Keychain — no re-prompt | **Pass** | ORS key present in data-protection vault (`com.routefinder.vault.*`); consecutive Keychain reads return same credential; packaged app has `keychain-access-groups`. GUI relaunch not exercised in agent session — confirm locally with **RouteFinderMac** scheme. |
| G1 | `33 sameswegen` → Norway | **Fail** | Live Pelias global search (no GBR boundary) returns Canada/Mexico/USA/Japan — not Ålesund. Overseas heuristic fires (`wegen` marker) but Pelias ranking is wrong for this exact query; Apple fallback does not run because Pelias returns non-empty results. `samesvegen ålesund` returns Norway via Pelias. |
| R1 | Long haul + LEZ avoid — no 2004 | **Pass** | `lezAvoidPolicyOmitsPolygonsOnLongHaul` (Norwich → Ålesund); live ORS HGV route Norwich → Edinburgh (611 km) succeeds with no avoid polygons on long haul. |
| S1 | 30 mph sim feel + centered camera | **Pass** (automated) | `defaultTrackingZoom_isPulledBackForHGVFeel` (15.0), `cameraFollowCenter_offsetsForwardHalfLength`, `maxUpcomingCurveSpeedMps_nearStraightDensifiedSpineAllowsResidentialCruise`. Visual 30 mph feel / turn pivot not re-run interactively in agent session. |

### Honest limits (post-fix pass)

- GUI launch of packaged `RouteFinder.app` was blocked in the agent environment (`Launchd job spawn failed`); use Xcode **RouteFinderMac** scheme or `open RouteFinder.app` locally for interactive confirmation.
- **G1 regression:** exact query `33 sameswegen` still does not surface Ålesund via Pelias despite global (non-UK) search. Follow-up: merge Apple worldwide fallback when overseas heuristic fires but top Pelias hits lack expected country markers, or append `ålesund`/`norway` bias for Nordic street suffixes.
- Visual sim feel (S1) and Keychain dialog absence (K1 relaunch) require local **RouteFinderMac** confirmation.

## Critical bugs found

None blocking. No Phase 20 hotfix required.
