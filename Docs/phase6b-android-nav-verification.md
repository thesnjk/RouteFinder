# Phase 6B — Android C2 navigation verification

Device QA for fleet-proxy HGV routing, MapLibre map, metric voice TBT, trip handoff, and physics rehearsal. **No driver HeiGIT key.**

Last updated: 2026-09-11

---

## Prep (3 min)

Same Wi‑Fi for Mac + Android. Terminal:

```bash
export ORS_API_KEY="your-heigit-key"
cd /Users/admin/Developer/RouteFinder/RouteFinder
swift run RouteFinderFleetServer --port 8080 --ors-key "$ORS_API_KEY"
```

Confirm `GET http://<mac-ip>:8080/v1/proxy/status` shows `orsConfigured: true`.

```bash
cd /Users/admin/Developer/RouteFinder/android-fleet-driver
./gradlew :app:assembleDebug
# Install debug APK on device/emulator
```

---

## First launch (3 min)

1. Accept **Driver Terms** (checkbox required)
2. Onboarding → Get started
3. Fleet wizard: Discover / paste URL → Test /health → Scan QR / UUID → Finish

| Check | Pass? |
|-------|-------|
| Terms gate blocks Continue until checked | |
| Wizard pairs without local ORS key | |

---

## MVP nav (8 min)

1. Origin: type `Norwich` → pick suggestion
2. Destination: type `King's Lynn` → pick suggestion
3. **Find route** → blue polyline on MapLibre map; distance + ORS ETA shown
4. **Start** → grant location; voice speaks metric prompts near maneuvers (400 metres / execute)
5. **Stop** when done

| Check | Pass? |
|-------|-------|
| HGV route via fleet proxy (no Settings API key) | **Exit gate** |
| Polyline visible | |
| Metric voice | |

---

## Fleet handoff (5 min)

1. From Mac or web dispatch: push a 2-stop trip to the paired vehicle
2. Android toast **Trip received**; origin/destination filled; route auto-calculates
3. **Start** → GPS snapshots update Mac/web Last GPS within ~60 s

| Check | Pass? |
|-------|-------|
| SSE → auto route | |
| Accept snapshot + GPS pin | |

---

## Wave 2 rehearse (3 min)

1. With a loaded route: tap **Rehearse**
2. Physics ETA appears (may differ from ORS ETA on grade)
3. If a fleet trip is active, snapshot includes `physicsETASeconds`

| Check | Pass? |
|-------|-------|
| Rehearse completes | |
| Physics ETA on brief / snapshot | |

---

## Automated

```bash
cd /Users/admin/Developer/RouteFinder/android-fleet-driver
./gradlew :app:testDebugUnitTest :app:assembleDebug
```

---

## Related

- [`android-fleet-driver/README.md`](../android-fleet-driver/README.md)
- [`android-c2-gate.md`](android-c2-gate.md)
- [`phase6-android-c1-verification.md`](phase6-android-c1-verification.md)
