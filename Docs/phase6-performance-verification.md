# Phase 6 — Performance verification

Engineering excellence track (`eng-p6-perf`). No legal/GTM.  
Last updated: 2026-09-19

**Goal:** Document ≥3 hotspot measurements and confirm demo script / scorecard engineering updates.

**Environment:** macOS (darwin), Xcode beta toolchain, JDK 17–22 for Android if re-run; date 2026-09-19.

---

## Hotspot measurements

| # | Hotspot | Method | Before | After |
|---|---------|--------|--------|-------|
| 1 | **Overpass lane cap** | `LaneGuidanceEnricherPerformanceTests` — 30 maneuvers, counting mock fetcher | Uncapped Overpass would fire **~28** junction queries (depart/arrive excluded) | **12** fetches with `.default` (`maxOverpassManeuvers: 12`) — **Pass** |
| 2 | **Offline corridor progress** | `offlineGraphStoreEnsureCorridorReportsMonotonicProgress` on Norfolk bbox synthetic tiles | Progress UX existed but unasserted | `progressEvents == cellCount`, monotonic `completed`, final `completed == total` — **Pass** |
| 3 | **Web map preview poll churn** | `tripMapFingerprint` in `smoke.mjs` + `TripMapPreview` effect deps | Marker effect re-ran on every **5 s** poll (new trip object / timestamp) | Fingerprint **stable** when only `driverLocationRecordedAt` changes; effect runs on geometry move only — **Pass** |
| 4 | **Fleet proxy 429 copy** (indicative) | `routeFailureMapperMapsFleetProxy429ToCapCopy` | Generic “Route Failed” / HTTP body | Title **Routing Cap Reached** + operator daily-cap message — **Pass** |
| 5 | **Predictive risk fuse** | `JobIntakePredictiveRiskTests.predictiveRiskEngineFusesThreeKinds` | Separate hazard / weather / kinetic banners | Unified `RouteRiskAdvisory` fuse ≥3 kinds + primary ahead — **Pass** (U3) |
| 6 | **Clearance Overpass cap** | `ClearanceCorridorProbe.maxElements` + fixture advisories | Unbounded corridor tags | Soft cap **80** elements/query; ledger `.overpass` — **Pass** (U9) |

### Manual / operator (not CI)

| Target | Status | Notes |
|--------|--------|-------|
| Cold route find UI responsive **&lt;3 s** on good network | **Pending local** | Norwich → King's Lynn with ORS keyed or fleet proxy; operator stopwatch |
| Navigation progress throttle without jank | **Accept as-is** | Existing ~10 s hazard/toll refresh; no change this phase |

---

## Automated gate

| Check | Command | Result |
|-------|---------|--------|
| Lane cap + offline progress | `swift test --filter laneGuidanceEnricherCapsOverpass` / `offlineGraphStoreEnsureCorridor` | **Pass** (2026-09-19) |
| Route failure 429 | `swift test --filter routeFailureMapperMapsFleetProxy429` | **Pass** |
| Full package | `cd RouteFinder && swift test` | **Pass** |
| Fleet smoke | `bash Scripts/fleet-e2e-smoke.sh` | **Pass** 13/13 |
| Web fingerprint + build | `cd web-dispatch && npm test && npm run build` | **Pass** |
| Hosted gateway | `cd hosted-gateway && npm test` | **Pass** |

**Sign-off:** `eng-p6-perf` — **completed** 2026-09-19

---

## Code surfaces

| Change | Path |
|--------|------|
| Lane cap tests | `RouteFinder/Tests/RouteControllerTests/LaneGuidanceEnricherPerformanceTests.swift` |
| Offline progress test | `RouteFinder/Tests/DataLayerTests/OfflineGraphStoreTests.swift` |
| Map fingerprint | `web-dispatch/src/tripMapFingerprint.ts`, `TripMapPreview.tsx`, `scripts/smoke.mjs` |
| 429 UX | `RouteFailurePresentation.swift`, `DispatchViewModel` geocode path |

---

## Related

- [`demo-superiority-script.md`](demo-superiority-script.md)
- [`engineering-test-matrix.md`](engineering-test-matrix.md)
- [`competitive-feature-scorecard.md`](competitive-feature-scorecard.md) — Phase 6 engineering section
