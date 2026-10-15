# Product screenshots

README / App Store source assets (not P0 QA evidence). Mask API keys before committing.

| File | Caption |
|------|---------|
| `ios-route-map.png` | iOS — HGV route ready (UK Artic · HeiGIT ORS) after seeded Find route |
| `ios-rehearse.png` | iOS — active navigation / rehearsal chrome (Stop while simulation runs) |
| `ios-dispatch-toast.png` | iOS — trip received toast (`New dispatch received — Norwich → King's Lynn`) |
| `web-dispatch-desk.png` | Web dispatch — Connected desk after Bootstrap demo fleet |

## Re-capture

### web-dispatch

```bash
# Terminal A — fleet (use a demo key; never commit real secrets)
cd RouteFinder && swift run RouteFinderFleetServer --port 8080 --api-key demokey

# Terminal B
cd web-dispatch && npm run dev -- --host 127.0.0.1 --port 5173
```

1. Open http://127.0.0.1:5173/
2. Paste the same Bearer as `--api-key` → **Test /health** → green **Connected**
3. **Bootstrap demo fleet**
4. Mask the API key field (blur / password style) → screenshot → `web-dispatch-desk.png`

### iOS Simulator

```bash
# From repo root — writes PNGs into Docs/screenshots/
xcodebuild test \
  -project RouteFinderApp.xcodeproj \
  -scheme RouteFinderApp \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  -only-testing:'RouteFinderAppUITests/ProductScreenshotsUITests/testCaptureProductScreenshots' \
  -parallel-testing-enabled NO
```

Launch args used by the helper: `UITEST_SKIP_AUTH`, `UITEST_SKIP_ONBOARDING`, `UITEST_SKIP_ROLE_PICKER`, `UITEST_SEED_ROUTE`, `UITEST_HGV_MODE`, `UITEST_PEEK_SHEET`, `UITEST_SEED_DISPATCH_TOAST`.

Do **not** commit: live API keys, Bearer tokens, personal addresses, or raw `Docs/qa-screenshots/` P0 dumps.
