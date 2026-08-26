# RouteFinder

Native **HGV / truck navigator** for Apple platforms (iOS 17+ / macOS 14+). RouteFinder plans constraint-aware routes, rehearses them with vehicle physics, and keeps hours-of-service as an **advisory** overlay — the digital tachograph remains the legal record.

Built as a Swift 6 Swift Package with SwiftUI, MapLibre (WKWebView), and HeiGIT OpenRouteService for global HGV routing.

## What it does

- **Constraint routing** — length / width / height / weight / axle / hazmat / ADR tunnel codes via OpenRouteService
- **Physics rehearsal** — pre-trip kinetic risk (grade, brake fade, slip) with a shareable trip brief (plain text or PDF)
- **Hours of service (advisory)** — EU Regulation 561 / Working Time Directive clock, rest insertion suggestions, driver-card JSON/DDD import, “Can I drive now?”
- **CarPlay** — turn-by-turn templates with voice coexistence hooks (iOS)
- **UK living layer** — plate → vehicle profile (RegCheck + DVLA), truck POIs (fuel / parking / weigh / layby), LEZ / restriction banners
- **Fleet MVP** — native dispatch console + disk-backed org → trip → physics ETA; optional **LAN sync** via `RouteFinderFleetServer`
- **Offline routing & maps** — H3 graph tiles + hybrid ORS/offline policy; optional local MapLibre map pack via on-device HTTP
- **Live traffic reroute** — TomTom flow sampling can trigger an ORS `avoid_polygons` recalculation
- **Walkaround checks** — local DVSA-style inspection checklist

## Legal notice (hours & tachograph)

**The vehicle unit (VU) / digital tachograph is authoritative.** RouteFinder’s HOS clock, imported card remainings, and “Can I drive now?” answers are planning aids only. Do not use them as a substitute for the legal tachograph record or for enforcement decisions.

## API keys

Keys are stored in the macOS/iOS Keychain for the local signed-in account (Settings sheet).

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

### macOS app

```bash
cd RouteFinder
swift run RouteFinderMacApp
```

Or open the package in Xcode and run the `RouteFinderMacApp` scheme.

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

On the driver iPhone (same Wi‑Fi/LAN), open **Settings → Fleet dispatch**, tap **Discover fleet servers on LAN**, pick the dispatch Mac entry (or manually enter `http://<dispatch-mac-ip>:8080` / `https://` when TLS is enabled), add the matching **Fleet API key** if required, and tap **Test fleet connection**. Store mode switches immediately — no app restart required. Open the **Dispatch Console** window on macOS to push trips; the driver polls as usual.

**LAN / VPN only.** Do not expose the fleet server to the public internet without proper network controls.

### iOS app

```bash
cd RouteFinder
# Prefer Xcode: open Package.swift, select RouteFinderIOS + a simulator/device
```

CarPlay entitlements live next to the iOS target. Use a development team with CarPlay capability for device testing.

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
- Tests use [Swift Testing](https://github.com/apple/swift-testing)

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
