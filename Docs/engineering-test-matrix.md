# Engineering test matrix

Engineering excellence Phase 5 (`eng-p5-tests`). No legal/GTM.  
Last updated: 2026-09-22

Maps **feature → test command** for demo-critical paths. Prefer targeted `--filter` runs while iterating; full suites before merge.

---

## Critical path

| Feature | Primary tests | Command |
|---------|---------------|---------|
| Route find (ORS payload + decode) | `OpenRouteServicePayloadBuilderTests`, `OpenRouteServiceRoutingClientTests`, `OpenRouteServiceErrorMappingTests` | `cd RouteFinder && swift test --filter OpenRouteService` |
| Fleet ORS proxy (no driver key) | `FleetORSRoutingFactoryTests`, `FleetProxyTests` | `swift test --filter FleetORS` / `--filter fleetProxy` |
| Fleet push + SSE | `fleetSSEClientReceivesTripPushedEvent`, `fleetE2EWorkflowPushSnapshotAndSSE` | `bash Scripts/fleet-e2e-smoke.sh` |
| Snapshot PUT (+ GPS pin) | `applySnapshotMergesDriverGPSOntoTrip`, `httpFleetStoreSyncsTripsOverLANServer`, E2E GPS asserts | `swift test --filter applySnapshotMergesDriverGPS` / E2E filter |
| Telematics ingest stub | `fleetTelematicsIngestPersists`, `fleetTelematicsIngestViaHTTP`, hosted `gateway.test.ts` | `swift test --filter fleetTelematics` ; `cd hosted-gateway && npm test` |
| Job intake + `FleetJobBrief` | `JobIntakePredictiveRiskTests`, `fleetCreateAndPushTripRoundTripsJobBrief` | `swift test --filter JobIntake` / `--filter RoundTripsJobBrief` |
| Predictive risk fuse | `JobIntakePredictiveRiskTests` (fuse ≥3 kinds + forecast/clearance/off-route), UITest `testPredictiveRiskPrimaryBannerOnSeededRoute` | `swift test --filter PredictiveRisk` / `--filter JobIntakePredictive` ; UITest seed `UITEST_SEED_PREDICTIVE_RISK` |
| Android job intake / ADR→ORS / time windows | `JobIntakeHandlerTest`, `TimeWindowRiskEvaluatorTest` | `cd android-fleet-driver && ./gradlew :app:testDebugUnitTest --tests '*JobIntake*' --tests '*TimeWindow*'` |
| Android forecast / clearance fuse | `ForecastAndClearanceRiskTest`, `PredictiveRiskEngineTest` | `./gradlew :app:testDebugUnitTest --tests '*Forecast*' --tests '*PredictiveRisk*'` |
| Android LEZ ORS avoid polygons (U15) | `ComplianceParityTest` (`lezAvoidPolicy*`, `orsDirectionsRequestEncodesAvoidPolygons*`) | `./gradlew :app:testDebugUnitTest --tests '*ComplianceParity*'` |
| Android fleet proxy 429 / daily-cap copy | `FleetProxyErrorMapperTest` | `./gradlew :app:testDebugUnitTest --tests '*FleetProxyErrorMapper*'` |
| Web fleet proxy 429 / geocode-cap copy | `scripts/smoke.mjs` (`fleetProxyUserMessage`) | `cd web-dispatch && npm test` |

---

## Fleet LAN

| Concern | Filter / script |
|---------|-----------------|
| HTTP trip sync | `httpFleetStoreSyncsTripsOverLANServer` |
| Store factory | `fleetStoreFactoryUsesDiskStoreByDefault`, `fleetStoreFactoryUsesHTTPStoreWhenRemoteEnabled` |
| SSE push | `fleetSSEClientReceivesTripPushedEvent` |
| SSE auth | `fleetSSEEndpointRejectsMissingAPIKeyWhenConfigured` |
| SSE heartbeat | `fleetSSEConnectionSurvivesHeartbeatInterval` |
| Bonjour | `fleetBonjour` |
| Push roles | `createAndPushTripAssignsStopRoles` |
| E2E push → SSE → snapshot → GPS → inspection | `fleetE2EWorkflowPushSnapshotAndSSE` |
| Proxy status | `fleetProxyStatusReportsORSConfigured` |
| Telematics store + HTTP | `fleetTelematicsIngestPersists`, `fleetTelematicsIngestViaHTTP` |
| GPS merge (in-memory) | `applySnapshotMergesDriverGPSOntoTrip` |
| Job brief wire round-trip | `fleetCreateAndPushTripRoundTripsJobBrief` |
| **Smoke script** | `bash Scripts/fleet-e2e-smoke.sh` (14 filters, includes `jobBrief`) |

SSE helpers: `waitForFleetServerReady`, `beginSSESubscription`, `awaitSSEEvent` in `FleetTestServerSupport.swift`.

---

## Dispatch GPS

| Layer | Test |
|-------|------|
| In-memory merge | `applySnapshotMergesDriverGPSOntoTrip` |
| JSON round-trip | `fleetTripSnapshotGPSRoundTripsThroughJSON` |
| HTTP LAN | `httpFleetStoreSyncsTripsOverLANServer` (driver lat/lon on snapshot) |
| E2E activeTrip pin | `fleetE2EWorkflowPushSnapshotAndSSE` asserts `driverLatitude` / `driverLongitude` on `activeTrip` |

---

## Phase 8 parity

| Concern | Command |
|---------|---------|
| UK toll catalog | `swift test --filter ukTollCatalog` |
| Toll matcher | `swift test --filter tollMatcher` |
| Parking partner links | `swift test --filter parkingPartnerLinks` |
| Lane OSM vs heuristic | `swift test --filter laneGuidanceSource` / `overpassPrefers` |
| Full suite file | `swift test --filter Phase8` (if named) or run filters above from `Phase8ParityTests.swift` |

---

## Android / hosted / web

| Surface | Command |
|---------|---------|
| Android unit + parsers | `cd android-fleet-driver && export JAVA_HOME=$(/usr/libexec/java_home -v 17 \|\| /usr/libexec/java_home -v 22) && ./gradlew :app:testDebugUnitTest --no-daemon` |
| Android HTTPS hosted URLs | `FleetOrsConfigTest.httpsHostedBaseUrls` |
| Hosted gateway | `cd hosted-gateway && npm test && npm run typecheck` |
| Web dispatch smoke | `cd web-dispatch && npm test` |

---

## iOS UITests (RouteFinderApp)

| Concern | Test | Notes |
|---------|------|-------|
| Cold launch | `testColdLaunchShowsAuthOrMap` | C1 |
| Walkaround entry | `testWalkaroundEntryExists` | Toolbar |
| Walkaround defect → Save | `testWalkaroundDefectNoteEnablesSave` | C3 — `UITEST_WALKAROUND_NEAR_COMPLETE` |
| Fuel card picker | `testFuelCardProviderPickerPersists` | C5 — Settings → Navigation |
| Hazard banner inject | `testHazardAheadBannerOnSeededRoute` | C6 — `UITEST_SEED_HAZARD_BANNER` |
| Roadworks banner inject | `testRoadworksAheadBannerOnSeededRoute` | C7 — `UITEST_SEED_ROADWORKS_BANNER` |
| Settings legal / API usage | `testSettingsAPIUsageAndLegalDriverTerms` | C8 |
| Fleet pair wizard | `testDriverPairFleetOpensWizard` | Phase 3 stranger UX |
| Role picker | `testLaunchRolePickerVisible` | Phase 3 |

```bash
xcodebuild test \
  -project RouteFinderApp.xcodeproj \
  -scheme RouteFinderApp \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:RouteFinderAppUITests
```

See also [`phase7-device-simulator-verification.md`](phase7-device-simulator-verification.md).

---

## CI mapping (`.github/workflows/ci.yml`)

| Job | What it runs |
|-----|----------------|
| `macos` | `swift build -c release`, `swift test`, `Scripts/fleet-e2e-smoke.sh` |
| `ios` | `RouteFinderIOS` simulator build + `RouteFinderAppUITests` |
| `web-dispatch` | `npm ci` → `npm test` → `npm run build` |
| `android-c1` | `./gradlew :app:testDebugUnitTest` + `assembleDebug` (JDK 17) |
| `hosted-gateway` | `npm test` + `npm run typecheck` |

---

## Disabled-test policy

**Rule:** Do not ship `@Test` / XCTest cases that are skipped, disabled, or `#expect(false)` placeholders without:

1. A linked GitHub issue (or ADR) describing why
2. An **owner** (person or team) in the issue

**Audit (2026-09-19):** No `XCTSkip`, disabled suites, or intentional skip markers found under `RouteFinder/Tests` or `RouteFinderAppUITests`.

---

## Phase 5 quality gate

| Check | Result |
|-------|--------|
| `swift test` | **Pass** (2026-09-22) |
| `fleet-e2e-smoke.sh` | **Pass** 14/14 (2026-09-22) |
| Android `./gradlew :app:testDebugUnitTest` | **Pass** (2026-09-22) |
| `hosted-gateway` `npm test` | **Pass** 8 tests (2026-09-19) |
| `web-dispatch` `npm test` | **Pass** (2026-09-22) — includes proxy-cap + inspection asserts |
| Critical path covered (route find, push, snapshot PUT+GPS, telematics HTTP) | **Yes** |
| No disabled tests without issue + owner | **Pass** (audit) |
| This matrix doc | **Present** |

**Sign-off:** `eng-p5-tests` — **completed** 2026-09-19; smoke filter count refreshed to **14/14** (includes `jobBrief`) 2026-09-22; Android/web proxy-cap rows added 2026-09-22


---

## Related

- [`phase4-platform-parity-verification.md`](phase4-platform-parity-verification.md)
- [`phase7-device-simulator-verification.md`](phase7-device-simulator-verification.md)
- [`phase8-parity-verification.md`](phase8-parity-verification.md)
- [`fleet-e2e-qa.md`](fleet-e2e-qa.md)
- [`engineering-benchmark-2026-09.md`](engineering-benchmark-2026-09.md)
- [`phase20-verification.md`](phase20-verification.md)
