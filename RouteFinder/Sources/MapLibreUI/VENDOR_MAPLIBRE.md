# Vendoring MapLibre GL JS for offline map rendering

RouteFinder embeds MapLibre via WKWebView. By default it loads JS/CSS from the CDN:

- `https://unpkg.com/maplibre-gl@4.7.1/dist/maplibre-gl.js`
- `https://unpkg.com/maplibre-gl@4.7.1/dist/maplibre-gl.css`

## Copy script (run from package root)

```bash
VERSION=4.7.1
DEST="RouteFinderApp"  # or copy into the RouteFinderIOS app target resources
mkdir -p "$DEST"
curl -fsSL "https://unpkg.com/maplibre-gl@${VERSION}/dist/maplibre-gl.js" \
  -o "$DEST/maplibre-gl.js"
curl -fsSL "https://unpkg.com/maplibre-gl@${VERSION}/dist/maplibre-gl.css" \
  -o "$DEST/maplibre-gl.css"
```

After copying, rebuild the `MapLibreUI` target. `MapLibreConfiguration` prefers
bundled files when present and falls back to the CDN otherwise.

## Offline map pack layout

Place a MapLibre style pack under Application Support:

```
~/Library/Application Support/RouteFinder/map-pack/
  style.json          # MapLibre style (sources should use relative or http://127.0.0.1 URLs)
  tiles/              # Optional raster/vector tile tree or PMTiles sidecar
  glyphs/             # Optional
  sprites/            # Optional
```

When Settings → “Use local map style when pack present” is on, RouteFinder starts
`LocalHTTPTileServer` on `127.0.0.1` and points MapLibre at
`http://127.0.0.1:<port>/style.json`.

Alternatively, a custom scheme `routefinder-tiles://` is reserved for a future
`WKURLSchemeHandler` path; the localhost server is the MVP approach.
