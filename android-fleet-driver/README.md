# RouteFinder Android Fleet Driver (C2 MVP)

Kotlin + Jetpack Compose **HGV navigator** using the office fleet ORS proxy (no customer API keys on the phone).

**In scope (C2 MVP + U10–U15):** Driver Terms, fleet wizard (C1), MapLibre Native map, Pelias geocode + ORS `driving-hgv` via `/v1/proxy/*`, metric voice TBT, SSE trip handoff, physics rehearsal, RegCheck, time windows, predictive fuse, fleet TomTom/OpenWeather/Overpass proxy, off-route clearance, DVSA walkaround photos + PDF, LEZ advisory + ORS `avoid_polygons`, HOS clock, layby ahead.

**Still deferred (product / operator):** Android Auto, offline graph/tiles, production CarPlay signing (Apple).

Fleet server forecast keys (office provides):

```bash
swift run RouteFinderFleetServer --port 8080 \
  --ors-key "$ORS_API_KEY" \
  --tomtom-key "$TOMTOM_API_KEY" \
  --openweather-key "$OPENWEATHER_API_KEY"
```

## Build

```bash
cd /Users/admin/Developer/RouteFinder/android-fleet-driver
./gradlew :app:testDebugUnitTest
./gradlew :app:assembleDebug
```

Use **JDK 17–22** for Gradle (CI uses 17). OpenJDK **25** fails the build with an opaque `25.0.2` error — e.g. `export JAVA_HOME=$(/usr/libexec/java_home -v 22)`.

CI: `android-c1` job in [`.github/workflows/ci.yml`](../.github/workflows/ci.yml) runs unit tests + assembleDebug.

## First-run flow

1. **Driver Terms** (required checkbox)
2. **Onboarding** (C2: receive + navigate)
3. **Fleet setup** — Discover on LAN / paste URL → Test /health → vehicle QR
4. **Navigation map** — search → Find route → Start / Rehearse; SSE trips auto-load

Emulator fleet URL default: `http://10.0.2.2:8080`.

## Module layout

```
fleet/     REST + SSE + prefs + Bonjour
routing/   FleetOrsConfig, Pelias, ORS HGV client + parsers
nav/       NavigationSession, progress, ViewModel
map/       MapLibreMapView + route line
voice/     ManeuverSpeechFormatter + TTS
physics/   RouteRehearsalEngine (Wave 2)
ui/        Terms, wizard, NavigationMapScreen, geocode field
```

## Device QA

[`Docs/phase6b-android-nav-verification.md`](../Docs/phase6b-android-nav-verification.md)

Gate notes: [`Docs/android-c2-gate.md`](../Docs/android-c2-gate.md)
