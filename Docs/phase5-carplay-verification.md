# Phase 5 — CarPlay production verification (paid team)

Device QA for CarPlay Maps + WeatherKit after restoring entitlements. Requires a **paid Apple Developer Program** team. Personal-team builds must keep entitlements empty — see rollback in [`carplay-weatherkit-restore.md`](carplay-weatherkit-restore.md).

Last updated: 2026-09-10

---

## Prep (5 min)

1. Apple Developer portal: App ID has **CarPlay Maps** + **WeatherKit** enabled; profiles regenerated ([restore guide Step 1](carplay-weatherkit-restore.md)).
2. Xcode → `RouteFinderApp` → Signing & Capabilities → **paid** team → Clean Build Folder → build for physical iPhone.
3. Confirm [`RouteFinderApp/RouteFinderApp.entitlements`](../RouteFinderApp/RouteFinderApp.entitlements) contains `com.apple.developer.carplay-maps` and `com.apple.developer.weatherkit`.
4. Same Wi‑Fi for Mac + iPhone. Fleet server (for fleet handoff scenarios):

```bash
export ORS_API_KEY="your-heigit-key"
cd /Users/admin/Developer/RouteFinder/RouteFinder
swift run RouteFinderFleetServer --port 8080 --ors-key "$ORS_API_KEY"
```

5. Pair iPhone via fleet setup wizard (no local HeiGIT key if ORS proxy is on). Optional: Mac Dispatch or web-dispatch for trip push ([phase1-device-checklist.md](phase1-device-checklist.md) / [phase4-dispatch-verification.md](phase4-dispatch-verification.md)).

---

## Entitlements (2 min)

| Check | Pass? | Notes |
|-------|-------|-------|
| Device build succeeds | | No provisioning errors for `carplay-maps` / `weatherkit` |
| Signing shows paid team | | Automatically manage signing ON |

---

## Solo route + CarPlay (5 min)

1. On iPhone: geocode a short UK route (e.g. Norwich → King's Lynn) → **Find route**.
2. Connect CarPlay: head unit **or** Xcode → **I/O → External Displays → CarPlay**.
3. Confirm map template appears on the CarPlay display.
4. **Start** navigation or simulation on the phone.
5. Confirm turn-by-turn maneuvers update on CarPlay; phone voice guidance coexists (no crash / stuck trip).

| Check | Pass? | Notes |
|-------|-------|-------|
| Map template on connect | | |
| TBT maneuvers update | | |
| Voice coexistence | | |

---

## Fleet handoff A — CarPlay already connected (5 min)

1. Connect CarPlay **before** dispatching.
2. From Mac or web: push a 2-stop fleet trip (e.g. Norwich → King's Lynn).
3. iPhone accepts / auto-applies trip → **Find route** runs (fleet proxy).
4. **Without** tapping Start: CarPlay should show a trip with fleet stop names (not generic Origin/Destination only).

| Check | Pass? | Notes |
|-------|-------|-------|
| Trip appears before Start | | `.routeLoaded` bootstrap |
| Stop names match fleet labels | | e.g. Norwich → King's Lynn |

---

## Fleet handoff B — connect after route loaded (3 min)

1. Disconnect CarPlay (or start without it).
2. Push / accept fleet trip → Find route completes on phone.
3. Connect CarPlay.
4. Trip appears with fleet stop names; route choice title includes origin → destination when dispatched.

| Check | Pass? | Notes |
|-------|-------|-------|
| Trip on connect after routeLoaded | | |
| Fleet stop names visible | | |

---

## Fleet handoff C — navigation with CarPlay (5 min)

1. With CarPlay connected and fleet route loaded: **Start** navigation or simulation.
2. Confirm progress estimates and upcoming maneuvers update on CarPlay.
3. Optional: trigger HOS advisory if available — CarPlay alert presents.

| Check | Pass? | Notes |
|-------|-------|-------|
| Progress / ETA updates | | |
| Maneuvers advance | | |
| No duplicate-trip crash | | |

---

## WeatherKit smoke (3 min)

1. Fresh install or clear OpenWeather key from Settings.
2. Open road-conditions / weather surface that auto-fetches.
3. Confirm fetch succeeds without entitlement error hints (`WeatherViewModel.lastError`).
4. Re-add OpenWeather key — OpenWeather remains preferred when present.

| Check | Pass? | Notes |
|-------|-------|-------|
| WeatherKit auto-fetch without OpenWeather | | |
| OpenWeather preferred when keyed | | |

---

## Automated

```bash
cd /Users/admin/Developer/RouteFinder/RouteFinder
swift test --filter CarPlayUITests
```

Expect: CarPlayUITests pass (iOS destination for full factory tests; macOS stub still green in package CI).

---

## Pass criteria / exit

| Check | Pass |
|-------|------|
| Paid-team signed build with entitlements | |
| Solo CarPlay TBT + voice | |
| Fleet handoff A (routeLoaded before Start) | |
| Fleet handoff B (connect after route) | |
| Fleet handoff C (nav progress) | |
| WeatherKit smoke (optional if time-boxed) | |
| `CarPlayUITests` green | |

When all required rows Pass, update [`phase20-verification.md`](phase20-verification.md): CarPlay row → **Pass**; scenario 8 → reference this checklist.

---

## Related

- [`carplay-weatherkit-restore.md`](carplay-weatherkit-restore.md) — portal + entitlements + rollback
- [`phase1-device-checklist.md`](phase1-device-checklist.md) — fleet pairing
- [`phase4-dispatch-verification.md`](phase4-dispatch-verification.md) — dispatch GPS
