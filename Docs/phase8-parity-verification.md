# Phase 8 — Competitive parity verification

Manual QA for toll hints, telematics stub, parking deep links, offline UX, and lane depth.

## Toll advisories

- [ ] Plan a route that passes Dartford or M6 Toll (or inject polyline in tests)
- [ ] Results / route summary shows **named** toll chips (advisory copy, not prices)
- [ ] During navigation within ~5 km, map chrome shows `TollAdvisoryBanner`
- [ ] Info link opens operator page when present

## Telematics (read-only)

- [ ] Settings → Fleet & Dispatch → Import CSV with headers `Device,Latitude,Longitude,DateTime`
- [ ] Sample rows appear; “Not legal VU” disclaimer visible
- [ ] Dispatch console status panel shows “Last telematics import: N vehicles…”
- [ ] Optional: `POST /v1/telematics/ingest` on LAN or hosted gateway with org/API token

## Parking partner links

- [ ] Layby banner → **Find parking (TRAVIS)** opens HTTPS map with lat/lng
- [ ] Truck POI overnight parking row shows TRAVIS + SNAP links
- [ ] Copy clarifies booking/fees are with the operator

## Offline pack UX

- [ ] Settings → Offline Routing → region picker (Norfolk / UK)
- [ ] Download shows linear progress
- [ ] Map pack section shows pack path; macOS **Reveal in Finder** works

## Lane guidance depth

- [ ] Online route: more maneuvers may show OSM lane strips
- [ ] Banner caption: “Lane data: OSM” vs “estimate”
- [ ] Approaching a junction with heuristic-only lanes may refresh from Overpass (network)

## Honest limits

- No live toll tariffs / booking commerce / remote VU / full HD lane maps
