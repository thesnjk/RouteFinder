# Phase 3 — Stranger UX verification (EPIC-STRANGER-UX)

Engineering excellence track. No legal/GTM.  
Last updated: 2026-09-21

**Goal:** Fleet pilot stranger path — role → pair fleet (no driver HeiGIT key) → Find route → Start Navigation — with fewer clicks than a CoPilot Account Manager seat dance.

---

## Automated gate

| Check | Command | Result |
|-------|---------|--------|
| Package tests (settings deep link) | `swift test --filter WorkspaceSettingsTests` | **Pass** (2026-09-18) |
| Fleet Part A | `./Scripts/fleet-e2e-smoke.sh` | **Pass** 14/14 (2026-09-21) |
| UITests (key cases) | `testDriverPairFleetOpensWizard`, cloud banner, settings legal, role picker | **Pass** |
| New: pair → wizard | `testDriverPairFleetOpensWizard` | **Pass** |
| Existing C1/C2/C8 proxies | cold launch / Start Navigation / settings hub (covered in suite) | **Pass** on prior Phase 2 run |
| **SSE auto-intake** | `FleetDispatchCoordinator.handleRemoteTripPushed` → `applyJobIntake` (auto find/rehearse) | **Pass** — **no Accept button**; driver gets toast + route load with **0 accept taps** |

---

## Stranger script — fleet proxy (target &lt;5 min, ≤8 taps to Find route)

**Setup (operator, not counted in driver taps):** Mac fleet server with ORS key:

```bash
cd RouteFinder && swift run RouteFinderFleetServer --port 8080 --ors-key "$ORS_API_KEY"
```

Dispatch: create org + vehicle, show QR.

### Driver taps (budget ≤8 before Find route)

| # | Action | Notes |
|---|--------|-------|
| 1 | Pick **Driver** | Launch role |
| 2 | Accept Driver Terms / Got it | Product sheet if first run |
| 3 | Pick **HGV** (or Car) | Vehicle mode |
| 4 | **Pair with fleet** | Opens wizard; remote sync **pre-enabled** |
| 5 | **Next** (connection kind LAN) | |
| 6 | Discover or paste URL → **Next** | |
| 7 | **Test connection** → **Next** | /health Connected |
| 8 | Scan QR / paste UUID → Save → **Finish** | Paired |

Then: search or map pin → **Find route** (no personal HeiGIT key) → Rehearse → **Start Navigation**.

**After pairing — zero-tap job intake:** When dispatch pushes a trip over SSE, the driver app applies stops + profile and auto-runs Find route (and optional Rehearse) with **no Accept tap**. Banner toast: “New dispatch received — loading route…”. Manual Accept is only for the legacy C1 home-screen demo path, not the C2 navigator.

**Solo path:** Driver setup → **Solo driver** → Settings opens on **API Keys** (deep link).

**Cloud banner:** When unkeyed and not on fleet proxy, chrome shows “Add API key or Pair with fleet” (`cloudRoutingBanner`). Hidden when `hasCloudRoutingCapability` (local ORS **or** fleet proxy).

---

## Dispatch desk smoke

| Surface | Check |
|---------|-------|
| Mac Dispatch | Health pill green when remote fleet URL reachable (`DispatchConsoleView`) |
| Mac map | Stop pins + driver `SimulatedVehicleState` when snapshot has lat/lon; region includes driver |
| Web | Test /health pill; geocode stops; `TripMapPreview` driver marker class `map-marker--driver` |

### Push → toast timing (LAN)

Median of 5 trials should be **&lt;10 s** (SSE). Log here when operator runs Part B:

| Trial | Seconds to toast | Notes |
|------:|-----------------|-------|
| 1 | | |
| 2 | | |
| 3 | | |
| 4 | | |
| 5 | | |
| **Median** | | Target &lt;10 |

---

## Code surfaces (Phase 3)

| Change | File |
|--------|------|
| Settings deep link `.apiKeys` | `NavigationWorkspaceSettings`, `SettingsSheet`, `ContentView` Solo CTA |
| Wizard pre-enables remote; Pair opens wizard as launch cover (not sheet) | `FleetSetupWizardView`, `ContentView` `.fleetWizard` |
| Banner copy | `IOSMapChrome.compactCloudBannerText` |
| Map region includes driver pin | `DispatchMapDetailView` |
| UITest | `testDriverPairFleetOpensWizard` + `UITEST_DRIVER_NEXT_STEPS` |

---

## Related

- [`getting-started.md`](getting-started.md)
- [`phase1-device-checklist.md`](phase1-device-checklist.md)
- [`engineering-benchmark-2026-09.md`](engineering-benchmark-2026-09.md) epic `#2`
