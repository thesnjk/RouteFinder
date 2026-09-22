# Phase 7 — Device / simulator P0 verification

Engineering excellence track (`eng-p7-p0`). No legal/GTM.  
Last updated: 2026-09-19

**Goal:** Consolidate Eng Phases 1–6 evidence into [`phase20-verification.md`](phase20-verification.md) and move UI-state-verifiable C3/C5/C6/C7 rows to **Pass (CI sim)** without claiming physical voice / TomTom / two-device LAN.

**Competitive edge:** Objective simulator ledger vs competitor demo scripts that stay forever “manual only.”

---

## UITests added

| ID | Test | Launch args |
|----|------|-------------|
| C3 | `testWalkaroundDefectNoteEnablesSave` | `UITEST_HGV_MODE`, `UITEST_WALKAROUND_NEAR_COMPLETE`, `UITEST_OPEN_WALKAROUND` |
| C5 | `testFuelCardProviderPickerPersists` | `UITEST_HGV_MODE`, `UITEST_OPEN_SETTINGS` |
| C6 | `testHazardAheadBannerOnSeededRoute` | `UITEST_SEED_ROUTE`, `UITEST_SEED_HAZARD_BANNER` |
| C7 | `testRoadworksAheadBannerOnSeededRoute` | `UITEST_SEED_ROUTE`, `UITEST_SEED_ROADWORKS_BANNER` |

DEBUG hooks: `UITestLaunchConfigurator`, `RouteViewModel.startWalkaroundInspection` (near-complete seed), `seedUITestMapBannersIfNeeded`.

---

## Commands

```bash
# Package
cd RouteFinder && swift test

# Fleet Part A (13 filters)
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

## Still operator-owned

| ID | Why not CI sim |
|----|----------------|
| **C4** | Requires hearing layby TTS on a live/sim GPS route |
| **C5** live fuel POI banner | Needs OSM fuel stop on corridor (picker persistence is CI) |
| **C6/C7** live report / OSM corridor | Inject proves chrome wiring only |
| **C9** | Live TomTom traffic sampling |
| **Fleet Part B** | Mac ↔ physical iPhone same Wi‑Fi |

Checklist: [`phase1-device-checklist.md`](phase1-device-checklist.md). Ledger: [`phase20-verification.md`](phase20-verification.md).

---

## Quality gate

| Criterion | Result |
|-----------|--------|
| phase20 Eng Phases 3–7 documented | **Pass** |
| Fleet smoke 13/13 | **Pass** (2026-09-19) |
| New UITests green | **Pass** — full `RouteFinderAppUITests` suite (18 cases) 2026-09-19 |
| Overlay walkaround Close/Save dismiss | **Pass** — `onFinished` clears `presentedModal` |
| C4 / C9 / Part B Pending local | **Accept** — operator |

**Sign-off:** `eng-p7-p0` — **completed** 2026-09-19
