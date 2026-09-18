# Phase 6A — Android C1 verification

15-minute LAN check that the Android fleet driver receives a web/Mac push and publishes a snapshot (with optional GPS pin).

Last updated: 2026-09-11

---

## Prep (3 min)

Same Wi‑Fi for Mac + Android phone (or emulator on the Mac).

```bash
export ORS_API_KEY="your-heigit-key"
cd /Users/admin/Developer/RouteFinder/RouteFinder
swift run RouteFinderFleetServer --port 8080 --ors-key "$ORS_API_KEY"
```

Build/install the APK:

```bash
cd /Users/admin/Developer/RouteFinder/android-fleet-driver
./gradlew :app:assembleDebug
# Install via Android Studio Run, or adb install app/build/outputs/apk/debug/app-debug.apk
```

Register a vehicle on Mac Dispatch or web-dispatch; note QR / UUID.

---

## Wizard (5 min)

1. Cold launch → onboarding → **Get started**
2. Enable → Next
3. **Discover on LAN** → pick Mac **or** paste `http://<mac-ip>:8080` (emulator: `http://10.0.2.2:8080`)
4. **Test /health** → Connected → Next
5. Paste UUID or **Scan QR** → Done (scan should skip straight to Done)
6. Optional **Check for dispatch** → Finish

| Check | Pass? | Notes |
|-------|-------|-------|
| Onboarding appears once | | |
| LAN discover or manual URL | | |
| Health gate blocks Next until Connected | | |
| QR / UUID pairs | | |

---

## Trip receive (5 min)

1. Home shows **Connected**, last health, **SSE listening**
2. From Mac or web: **Push trip** to the paired vehicle
3. Trip card appears (or tap **Check for dispatch**)
4. **Accept / publish snapshot**
5. Grant location → wait ~30 s → Mac/web **Last GPS** / driver pin updates

| Check | Pass? | Notes |
|-------|-------|-------|
| Trip from push | | Exit gate |
| Accept snapshot | | |
| GPS pin (optional) | | |

---

## Resilience smoke (2 min)

1. Stop fleet server briefly → home shows Offline / SSE reconnecting
2. Restart server → **Refresh now** or wait for poll → Connected + SSE listening again

---

## Automated

```bash
cd /Users/admin/Developer/RouteFinder/android-fleet-driver
./gradlew :app:testDebugUnitTest :app:assembleDebug
```

---

## Related

- [`android-fleet-driver/README.md`](../android-fleet-driver/README.md)
- [`fleet-setup-guide.md`](fleet-setup-guide.md)
- [`getting-started.md`](getting-started.md#im-an-android-fleet-driver-c1--stranger-test)
