# RouteFinder Android Fleet Driver (C1)

Kotlin + Jetpack Compose scaffold for the **fleet trip receive** client.

**In scope (C1):** connect to `RouteFinderFleetServer`, subscribe to SSE, show active trip stops, publish a basic snapshot / accept status.

**Out of scope (C2):** full HGV navigator, physics rehearsal, offline graph, Android Auto — see [`Docs/android-c2-gate.md`](../Docs/android-c2-gate.md).

## Open in Android Studio

1. Install Android Studio Ladybug+ with JDK 17.
2. **File → Open** → `/Users/admin/Developer/RouteFinder/android-fleet-driver`
3. Sync Gradle → Run on emulator or device (same Wi‑Fi as fleet server).

```bash
cd /Users/admin/Developer/RouteFinder/android-fleet-driver
./gradlew :app:assembleDebug
```

## Configure

In-app Settings (or `local.properties` overrides later):

| Field | Example |
|-------|---------|
| Server base URL | `http://192.168.1.10:8080` |
| API key | optional Bearer key |
| Vehicle UUID | from web/Mac dispatch console |

## Module layout

```
android-fleet-driver/
  app/src/main/java/com/routefinder/fleetdriver/
    MainActivity.kt
    ui/DriverScreen.kt
    fleet/FleetApi.kt
    fleet/FleetModels.kt
    fleet/FleetSseClient.kt
```
