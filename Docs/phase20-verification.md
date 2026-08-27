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
| UK LEZ banners | `UKLowEmissionZoneCatalog` along-route announcements | Present (alert only — no avoid-on-route) |
| CarPlay | Code present; entitlements emptied for personal team | **Degraded** — not device-QA’d on personal team |
| WeatherKit | Fallback when no OpenWeather key | **Degraded** on personal team (no entitlement) |

## Automated evidence

| Check | Result |
|---|---|
| `swift test` (package) | **Pass** — 372 tests |
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

## Critical bugs found

None blocking. No Phase 20 hotfix required.
