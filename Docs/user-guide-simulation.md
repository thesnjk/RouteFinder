# Route simulation and rehearsal — user guide

This guide explains the simulation controls in RouteFinderMac and RouteFinder iOS after you have calculated a route.

## Rehearse Route

**Rehearse Route** runs a **headless physics simulation** over the entire route in the background. It does **not** move the vehicle on the map.

What it does:

- Integrates vehicle physics at 100× speed (typically completes in seconds on your Mac)
- Produces a **kinetic physics ETA** that accounts for speed limits, grades, signals, and (optionally) live traffic
- Updates the trip brief text you can share (plain text or PDF)
- Can publish a fleet dispatch snapshot when a dispatch trip is active

When to use it:

- Before a long haul, to compare web routing ETA vs physics-predicted ETA
- To generate a shareable trip brief for a client or depot

Rehearse is also triggered automatically in the background when a route loads (**Refining physics ETA…**). If rehearsal times out or fails, the app keeps the web routing ETA.

## Play / pause and speed multipliers (1×, 5×, 10×, 50×)

These controls run **live map playback**:

- The oriented vehicle footprint moves along the route
- The speed dial shows current speed and the legal limit
- Lane guidance banners update as you approach junctions

Speed multipliers only affect **playback speed on the map**. They do **not** change stored ETAs or Rehearse results.

## Traffic delay banner

After route find, RouteFinder may sample TomTom traffic along the corridor. A banner appears only when:

1. **Checking alternate…** — evaluation is in progress (usually brief; long routes may take up to ~30 seconds)
2. **Congestion detected on corridor** — a standstill or road closure was found **and** OpenRouteService returned a meaningfully faster alternate

Tap **Recalculate** to apply the traffic-aware alternate.

To disable reroute evaluation: **Settings → Navigation → Avoid traffic delays when routing** (off).

**Apply live traffic to cruise speed** is separate: it caps simulation cruise speed during playback/rehearsal but does not control the reroute banner.

## Lane guidance banner

When OSM `turn:lanes` data is available (or a maneuver heuristic applies), a banner shows which lane to use, for example **Use lane 2**. The strip shows lanes left-to-right; highlighted lanes are recommended.

Lane guidance appears:

- After route find (heuristics immediately; Overpass enrichment in the background when online)
- During simulation and live navigation near the upcoming maneuver

## Vehicle on the map

RouteFinder draws your vehicle as a **2D oriented footprint** (not a 3D model):

- **Passenger cars** — single sky-blue polygon sized to your registered dimensions
- **HGV** — cab + trailer polygons when length ≥ 6 m

During simulation the **green start pin is hidden** so the vehicle footprint is not confused with the origin marker. Zoom in while tracking to see the full polygon; at low zoom a blue circle may be used when not tracking.

## Search language (Settings)

**Settings → Search language**:

- **Display language** — passed to Pelias geocoding (`lang` parameter)
- **English name fallback** — when few localized results are found, also searches in English (helpful for Warsaw, Paris, etc.)

Characters you type (e.g. `Sørnesvegen`, `Ålesund`) are preserved in search results and pin labels. Basemap road names still follow the OpenFreeMap tile language.

## Quick reference

| Control | Moves map vehicle? | Changes ETA? |
|--------|-------------------|--------------|
| Rehearse Route | No | Yes (physics ETA) |
| Play / speed multipliers | Yes | No (live remaining ETA uses current speed) |
| Traffic Recalculate | No (new route geometry) | Yes (web routing ETA) |
