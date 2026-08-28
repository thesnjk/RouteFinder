# RouteFinder

Native **HGV / truck navigator** for Apple platforms (iOS 17+ / macOS 14+). RouteFinder plans constraint-aware routes, rehearses them with vehicle physics, and keeps hours-of-service as an **advisory** overlay — the digital tachograph remains the legal record.

Built as a Swift 6 Swift Package with SwiftUI, MapLibre (WKWebView), and HeiGIT OpenRouteService for global HGV routing.

## User guide

- [Route simulation and rehearsal](Docs/user-guide-simulation.md) — Rehearse Route vs Play, traffic banner, lane guidance, vehicle footprint, language settings
- [Fleet E2E QA playbook](Docs/fleet-e2e-qa.md) — Automated fleet smoke script + Mac/iPhone LAN checklist
- [CarPlay + WeatherKit restore](Docs/carplay-weatherkit-restore.md) — Paid-team entitlement restore (personal team: use OpenWeather instead)

## What it does

- **Constraint routing** — length / width / height / weight / axle / hazmat / ADR tunnel codes via OpenRouteService
- **Physics rehearsal** — pre-trip kinetic risk (grade, brake fade, slip) with a shareable trip brief (plain text or PDF with route map when geometry is available)
- **Hours of service (advisory)** — EU Regulation 561 / Working Time Directive clock, rest insertion suggestions, driver-card JSON/DDD import, “Can I drive now?”
- **CarPlay** — turn-by-turn templates with voice coexistence hooks (iOS)
- **UK living layer** — plate → vehicle profile (RegCheck + DVLA), truck POIs (fuel / parking / weigh / layby), LEZ / CAZ banners **and avoid-on-route** using simplified authored zone rings for non-compliant emission classes (Settings toggle; envelopes are approximate, not legal cadastral), on-device layby occupancy taps with age-weighted priors and last-seen banner copy (Looks full / Has spaces)
- **Fleet MVP** — native dispatch console + disk-backed org → trip → physics ETA; optional **LAN sync** via `RouteFinderFleetServer`
- **Offline routing & maps** — H3 graph tiles + hybrid ORS/offline policy; optional local MapLibre map pack via on-device HTTP
- **Live traffic reroute** — TomTom flow sampling can trigger an ORS `avoid_polygons` recalculation
- **Walkaround checks** — local DVSA-style inspection checklist
- **Sim UX** — Touch ID session restore, vehicle workspace snapshot, traffic cruise toggle (default off), center-anchored cab/trailer map model, OSM lane guidance banner

## Legal notice (hours & tachograph)

**The vehicle unit (VU) / digital tachograph is authoritative.** RouteFinder’s HOS clock, imported card remainings, and “Can I drive now?” answers are planning aids only. Do not use them as a substitute for the legal tachograph record or for enforcement decisions.

## API keys

Keys are stored in the macOS/iOS **data-protection** Keychain for the local signed-in account (Settings sheet).

**Mac day-to-day:** open [`RouteFinderApp.xcodeproj`](RouteFinderApp.xcodeproj) and run the **`RouteFinderMac`** scheme (signed `.app` with Keychain access group). After updating, log in once — allow any leftover login-Keychain prompt **once**, then re-save the ORS key in Settings if empty. Later launches must not re-prompt. If they do, Keychain Access → delete `com.routefinder.vault.*` (login keychain) → re-save keys.

Bare `swift run RouteFinderMacApp` has no Keychain entitlements — **Always Allow will not stick** across rebuilds (legacy login Keychain ACL).

The packaged `./Scripts/package-macos-app.sh` fallback requires an **Apple Development** signing identity and hardened runtime; ad-hoc signing will crash at launch (`Invalid Signature` on macOS 26). **Use the Xcode `RouteFinderMac` scheme** whenever possible.

| Key | Purpose | Required? |
|---|---|---|
| **OpenRouteService (HeiGIT)** | Geocoding + HGV routing | Yes for cloud routing |
| **TomTom Traffic Flow** | Live congestion scaling in simulation / reroute | Optional |
| **DVLA Vehicle Enquiry** | UK plate fallback lookup | Optional |
| **RegCheck username** | Primary UK registration dimensions | Optional (recommended for HGV) |
| **OpenWeather** | Live weather-aware road conditions | Optional |

Obtain ORS access from [HeiGIT / OpenRouteService](https://openrouteservice.org/). RegCheck: [regcheck.org.uk](https://www.regcheck.org.uk/). DVLA VES: [GOV.UK API catalogue](https://www.api.gov.uk/).

## How to run

Package root: `RouteFinder/` (contains `Package.swift`).

### SPM / CLI

```bash
cd RouteFinder
swift build
swift test
swift run RouteFinder -- help
```

### macOS app (preferred)

Requires **full Xcode** (not Command Line Tools only):

```bash
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
```

```bash
# From repo root — signed .app, data-protection Keychain
open RouteFinderApp.xcodeproj
# Scheme: RouteFinderMac  →  Run
```

Packaged SPM bundle (fallback; needs Apple Development cert + hardened runtime):

```bash
cd RouteFinder
./Scripts/package-macos-app.sh open
```

Dev-only bare executable (Keychain Always Allow will re-prompt on every rebuild):

```bash
cd RouteFinder
swift run RouteFinderMacApp
```

### Fleet LAN server (multi-device sync)

On the dispatch Mac, start the fleet HTTP server (default port 8080). Bonjour advertisement is enabled by default:

```bash
cd RouteFinder
swift run RouteFinderFleetServer --port 8080
```

Disable Bonjour for headless/CI with `--no-bonjour`.

Optional shared-secret auth and TLS:

```bash
swift run RouteFinderFleetServer --port 8080 --api-key "$ROUTEFINDER_FLEET_API_KEY" \
  --tls-cert /path/to/cert.pem --tls-key /path/to/key.pem
```

For LAN HTTPS with a self-signed certificate, [mkcert](https://github.com/FiloSottile/mkcert) is a convenient option (`mkcert -install && mkcert localhost 192.168.x.x`).

On the driver iPhone (same Wi‑Fi/LAN), open **Settings → Fleet dispatch**, tap **Discover fleet servers on LAN**, pick the dispatch Mac entry (or manually enter `http://<dispatch-mac-ip>:8080` / `https://` when TLS is enabled), add the matching **Fleet API key** if required, and tap **Test fleet connection**. Store mode switches immediately — no app restart required. When remote fleet sync is enabled, the driver app subscribes to dispatch events over **SSE** (`GET /v1/vehicles/{id}/events`) for near-instant trip delivery, with a 30-second fallback poll for resilience. Open the **Dispatch Console** window on macOS to push trips.

**Fleet QA playbook:** See [Docs/fleet-e2e-qa.md](Docs/fleet-e2e-qa.md) for automated smoke (`RouteFinder/Scripts/fleet-e2e-smoke.sh`) and Mac↔iPhone manual checklist.

**LAN / VPN only.** Do not expose the fleet server to the public internet without proper network controls.

### iOS app

```bash
cd RouteFinder
# Prefer Xcode: open Package.swift, select RouteFinderIOS + a simulator/device
```

CarPlay entitlements live next to the RouteFinderIOS Swift package target. Use a development team with CarPlay capability for in-car device testing.

Personal (free) Apple teams: `RouteFinderApp` ships without WeatherKit or CarPlay entitlements. Add an **OpenWeather** API key in Settings for live auto weather (preferred when present; takes effect immediately after save, no restart); otherwise use manual road-condition override. In-car CarPlay UI stays disabled without a paid-team entitlement. Fleet dispatch and routing work normally. When using a **paid** Apple Developer Program team, follow [`Docs/carplay-weatherkit-restore.md`](Docs/carplay-weatherkit-restore.md) to restore WeatherKit/CarPlay entitlements in [`RouteFinderApp/RouteFinderApp.entitlements`](../RouteFinderApp/RouteFinderApp.entitlements).

**Personal team verification checklist** (verified 2026-08-27 on Xcode 26 / iOS 26.5 SDK):

- Open [`RouteFinderApp.xcodeproj`](../RouteFinderApp.xcodeproj) (not the SPM package alone).
- **Product → Clean Build Folder**, then build for **iOS Simulator** or a registered device with **Signing → Automatic** and your personal team.
- Confirm [`RouteFinderApp/RouteFinderApp.entitlements`](../RouteFinderApp/RouteFinderApp.entitlements) is an empty plist — the signed app should contain only `application-identifier`, `com.apple.developer.team-identifier`, and `get-task-allow` (no WeatherKit or CarPlay).
- Expect **no signing/provisioning errors** for `com.apple.developer.weatherkit` or `com.apple.developer.carplay-maps`.
- **Runtime limitations on personal team:** Without an OpenWeather key, WeatherKit auto-fetch fails gracefully (`WeatherViewModel.lastError` includes a Settings hint). Saving an OpenWeather key in Settings (or `OPENWEATHER_API_KEY`) switches live auto weather to OpenWeather immediately — no app restart. CarPlay scene wiring is present in `Info.plist` but in-car UI will not connect without a paid-team CarPlay entitlement.
- `swift test` (435 tests) and `xcodebuild -scheme RouteFinderApp` succeed with zero app-target Swift compiler warnings. Phase 20 claim inventory + QA log: [`Docs/phase20-verification.md`](Docs/phase20-verification.md); competitive matrix: [`Docs/competitive-gap-matrix.md`](Docs/competitive-gap-matrix.md).

Optional CLI build (requires full Xcode selected, not Command Line Tools only):

```bash
sudo xcode-select -s /Applications/Xcode.app
cd ~/Developer/RouteFinder
xcodebuild build -project RouteFinderApp.xcodeproj -scheme RouteFinderApp \
  -destination 'generic/platform=iOS Simulator' -configuration Debug
```

### Scripts

- `Scripts/preprocess-osm.sh` — synthetic or CSV → H3 tiles  
- `Scripts/build-global-tiles.sh` — OSM PBF (via osmium) → H3 `.graphjson` tiles  
- `Scripts/package-macos-app.sh` — package a macOS app bundle  

## Offline tiles / map pack layout

Default online maps use OpenFreeMap styles. For offline **routing** graphs:

```text
tiles/<region>/
  index.json                 # H3 tile index
  <h3cell>.graphjson         # nodes + edges per cell
```

Build example:

```bash
./Scripts/build-global-tiles.sh \
  --pbf ./data/norfolk.osm.pbf \
  --output ./tiles/norfolk \
  --resolution 7
```

Serve packs from a CDN or local path. Attribution for OpenStreetMap data must remain visible. Full planet PBF parsing in-process is not shipped — use the osmium + preprocessor pipeline.

## Architecture (short)

| Module | Role |
|---|---|
| `Contracts` | Shared domain types & ports |
| `DataLayer` | HOS clock, DDD import, POIs, tiles, Keychain |
| `RouteController` | ORS clients, planners, registries |
| `NavigationCore` | Progress, geometry, maneuvers |
| `MapLibreUI` / `CarPlayUI` / `UI` | Presentation |

## Development notes

- Swift 5.9+ / tools version 6.0, strict concurrency
- UI surfaces use `GlassmorphicModifiers` (`glassPanel`, `controlSheetStyle`, …)
- Tests use Swift Testing (`import Testing`) from the **Swift 6 / Xcode 16+ built-in module**. Do not add the `swift-testing` package — the 0.99.x release is a deprecation shim that still requires the toolchain copy and causes `_TestingInternals` link failures when Command Line Tools are selected.

### Swift Testing troubleshooting

`swift test` requires a full Xcode installation. **Command Line Tools alone are insufficient** — they do not ship `_TestingInternals`.

Point `xcode-select` at your Xcode app (release or beta):

```bash
cd ~/Developer/RouteFinder/RouteFinder
xcode-select -p
# Must NOT be: /Library/Developer/CommandLineTools

# Example: Xcode in Applications
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer

# Example: Xcode beta in Downloads
sudo xcode-select -s ~/Downloads/Xcode-beta.app/Contents/Developer

which swift
swift --version
# Must report Swift 6.x from Xcode, not Command Line Tools

rm -rf .build
swift package clean
swift package resolve
swift test
```

If built-in Testing still fails after switching to full Xcode, pin `swift-testing` to a **pre-0.99** tag (e.g. `0.10.0`) as a last resort — not 0.99.x.

### Git, Xcode, and iCloud

Keep the clone on **local disk** (e.g. `~/Developer/RouteFinder`), not in iCloud-synced **Documents**. iCloud File Provider often delays or drops file-change events, so Xcode Source Control may show only a stale `xcschememanagement` change while Terminal still lists the real diff.

If Xcode’s Changes list looks wrong:

1. Confirm you opened `RouteFinderApp.xcodeproj` under this repo (not a duplicate copy elsewhere).
2. **Source Control → Refresh File Status**, or quit and reopen Xcode.
3. Leave **Amend** off unless you mean to rewrite the latest commit.
4. **Uncheck** any `xcuserdata/` files when committing — they are per-machine IDE state (ignored by `.gitignore`; previously tracked copies are being removed from Git).

Verify from Terminal:

```bash
cd "/path/to/RouteFinder"
git status -sb
```

## Licence & data

Map data © OpenStreetMap contributors. Third-party APIs are subject to their own terms. RouteFinder does not provide legal advice on drivers’ hours.
