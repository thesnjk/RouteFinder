# Phase 7 — Device / simulator P0 verification

Engineering excellence track (`eng-p7-p0`). No legal/GTM.  
Last updated: 2026-11-11 (Phase 7b — C4 / C9 / Part B CI-sim close)

**Goal:** Consolidate Eng Phases 1–6 evidence into [`phase20-verification.md`](phase20-verification.md) and move UI-state-verifiable C3–C9 / Part B rows to **Pass (CI sim)** without claiming physical voice / live TomTom GPS / two-device LAN.

**Competitive edge:** Objective simulator ledger vs competitor demo scripts that stay forever “manual only.”

---

## UITests added

| ID | Test | Launch args |
|----|------|-------------|
| C3 | `testWalkaroundDefectNoteEnablesSave` | `UITEST_HGV_MODE`, `UITEST_WALKAROUND_NEAR_COMPLETE`, `UITEST_OPEN_WALKAROUND` |
| C4 | `testLaybyAheadBannerOnSeededRoute` | `UITEST_SEED_ROUTE`, `UITEST_HGV_MODE`, `UITEST_SEED_LAYBY_ADVISORY` |
| C5 | `testFuelCardProviderPickerPersists` | `UITEST_HGV_MODE`, `UITEST_OPEN_SETTINGS` |
| C6 | `testHazardAheadBannerOnSeededRoute` | `UITEST_SEED_ROUTE`, `UITEST_SEED_HAZARD_BANNER` |
| C7 | `testRoadworksAheadBannerOnSeededRoute` | `UITEST_SEED_ROUTE`, `UITEST_SEED_ROADWORKS_BANNER` |
| C9 | `testTomTomHazardBannerOnSeededRoute` | `UITEST_SEED_ROUTE`, `UITEST_SEED_TOMTOM_HAZARD_BANNER` |

DEBUG hooks: `UITestLaunchConfigurator`, `RouteViewModel.startWalkaroundInspection` (near-complete seed), `seedUITestMapBannersIfNeeded` (hazard / TomTom / roadworks / layby).

### Fleet Part B (CI)

| Check | Evidence |
|-------|----------|
| Inspection snapshot round-trip | `fleetInspectionSummaryRoundTripsViaSnapshot` (+ existing `fleetE2EWorkflowPushSnapshotAndSSE`) via `Scripts/fleet-e2e-smoke.sh` |
| Desk copy helpers | `web-dispatch/scripts/smoke.mjs` mirrors `inspectionSummary.ts` |
| iOS toast chrome | `UITEST_SEED_DISPATCH_TOAST` + C3 walkaround UITest |

---

## Commands

```bash
# Package
cd RouteFinder && swift test

# Fleet Part A (+ Part B inspection filter)
bash Scripts/fleet-e2e-smoke.sh

# iOS UITests (adjust simulator name as needed)
xcrun simctl shutdown all || true
xcodebuild test \
  -project ../RouteFinderApp.xcodeproj \
  -scheme RouteFinderApp \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:RouteFinderAppUITests

# Web / hosted / Android
cd ../web-dispatch && npm test
cd ../hosted-gateway && npm test
cd ../android-fleet-driver && \
  export JAVA_HOME=$(/usr/libexec/java_home -v 22 2>/dev/null || /usr/libexec/java_home -v 17) && \
  ./gradlew :app:testDebugUnitTest --no-daemon
```

---

## Optional operator residuals (not programme gates)

| ID | Why still optional |
|----|--------------------|
| **C4 hear-once** | Hearing layby TTS on a live/sim GPS route |
| **C5 live fuel POI banner** | Needs OSM fuel stop on corridor (picker persistence is CI) |
| **C6/C7 live report / OSM corridor** | Inject proves chrome wiring only |
| **C9 live GPS TomTom** | Real TomTom traffic sampling during nav |
| **Fleet Part B physical LAN** | Mac ↔ physical iPhone same Wi‑Fi toast / desk card |

Physical smoke: [`phase1-device-checklist.md`](phase1-device-checklist.md) (optional Block 1b). Ledger: [`phase20-verification.md`](phase20-verification.md).

---

## Quality gate

| Criterion | Result |
|-----------|--------|
| phase20 Eng Phases 3–7 documented | **Pass** |
| Fleet smoke (incl. inspection filter) | **Pass** — `fleetInspectionSummaryRoundTripsViaSnapshot` 2026-11-11 |
| Phase 7 UITests green | **Pass** — C3/C5/C6/C7 2026-09-19 |
| Phase 7b C4/C9 UITests + seeds | **Pass** — `testLaybyAheadBannerOnSeededRoute`, `testTomTomHazardBannerOnSeededRoute` 2026-11-11 |
| Overlay walkaround Close/Save dismiss | **Pass** — `onFinished` clears `presentedModal` |
| C4 / C9 / Part B programme gate | **Pass (CI sim / CI)** — physical residuals optional |

**Sign-off:** `eng-p7-p0` — **completed** 2026-09-19; **Phase 7b** — **completed** 2026-11-11
