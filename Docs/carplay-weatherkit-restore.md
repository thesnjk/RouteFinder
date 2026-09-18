# CarPlay + WeatherKit entitlement restore

Restore in-car navigation and Apple WeatherKit auto-fetch on **paid Apple Developer Program** builds. Personal (free) teams must keep [`RouteFinderApp/RouteFinderApp.entitlements`](../RouteFinderApp/RouteFinderApp.entitlements) empty and use **OpenWeather** in Settings instead.

Last updated: 2026-08-28 (Phase 28)

---

## When to use this guide

| Team type | CarPlay | WeatherKit auto-fetch |
|---|---|---|
| Personal (free) | Disabled — code present, entitlements empty | Use OpenWeather key in Settings |
| Paid Developer Program | Follow this guide | Follow this guide (OpenWeather still preferred when keyed) |

**Do not** add CarPlay or WeatherKit keys to the app entitlements on a personal team — Xcode signing will fail with provisioning errors for `com.apple.developer.carplay-maps` and `com.apple.developer.weatherkit`.

---

## Reference entitlements

The Swift Package iOS target already declares the intended keys in [`RouteFinder/Sources/RouteFinderIOS/RouteFinderIOS.entitlements`](../RouteFinder/Sources/RouteFinderIOS/RouteFinderIOS.entitlements):

```xml
<key>com.apple.developer.carplay-maps</key>
<true/>
<key>com.apple.developer.weatherkit</key>
<true/>
```

CarPlay-only reference: [`RouteFinderIOS.carplay.entitlements`](../RouteFinder/Sources/RouteFinderIOS/RouteFinderIOS.carplay.entitlements).

The signed **RouteFinderApp** target includes CarPlay Maps + WeatherKit keys for **paid-team** signing. Personal (free) teams must revert to an empty `<dict/>` per Rollback below.

---

## Step 1 — Apple Developer portal

1. Sign in to [Apple Developer](https://developer.apple.com/account).
2. Open **Certificates, Identifiers & Profiles → Identifiers**.
3. Select the RouteFinder app ID (matches `RouteFinderApp` bundle identifier).
4. Enable **CarPlay Maps** and **WeatherKit** capabilities.
5. Save and regenerate provisioning profiles (Development + Distribution as needed).

CarPlay Maps may require Apple approval for your app category — follow portal prompts if capability is gated.

---

## Step 2 — Merge entitlements into RouteFinderApp

Edit [`RouteFinderApp/RouteFinderApp.entitlements`](../RouteFinderApp/RouteFinderApp.entitlements) to match the reference:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.developer.carplay-maps</key>
    <true/>
    <key>com.apple.developer.weatherkit</key>
    <true/>
</dict>
</plist>
```

Commit this change only on a branch intended for paid-team signing.

---

## Step 3 — Xcode signing

1. Open [`RouteFinderApp.xcodeproj`](../RouteFinderApp.xcodeproj).
2. Select **RouteFinderApp** target → **Signing & Capabilities**.
3. Choose your **paid** team; enable **Automatically manage signing**.
4. Confirm CarPlay Maps and WeatherKit appear under capabilities (Xcode may add them from the entitlements file).
5. **Product → Clean Build Folder**, then build for a physical device.

Expected: no errors for `com.apple.developer.weatherkit` or `com.apple.developer.carplay-maps`.

---

## Step 4 — Device QA

### CarPlay

1. Connect iPhone to a CarPlay head unit or simulator (Xcode → **I/O → External Displays → CarPlay**).
2. Launch RouteFinder; start navigation on a calculated route.
3. Confirm turn-by-turn templates appear on the CarPlay display and voice guidance coexists with CarPlay prompts.

### WeatherKit

1. Remove OpenWeather key from Settings (or use a fresh install).
2. Confirm live road-condition auto-fetch succeeds without `WeatherViewModel.lastError` entitlement hints.
3. Re-add OpenWeather key — confirm OpenWeather remains preferred when present (Phase 17 behavior).

---

## Rollback (personal team builds)

To return to personal-team-safe signing:

1. Replace `RouteFinderApp.entitlements` with an empty `<dict/>` plist.
2. Clean build folder and rebuild.

Routing, fleet dispatch, physics rehearsal, and OpenWeather weather continue to work without CarPlay/WeatherKit.

---

## Related docs

- [README — Personal team verification](../README.md#ios-app)
- [Phase 5 CarPlay verification checklist](phase5-carplay-verification.md)
- [Phase 20 verification — scenario 8](phase20-verification.md)
- [Competitive gap matrix — Phase 28+ backlog](competitive-gap-matrix.md)
