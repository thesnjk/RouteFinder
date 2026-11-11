# Developer map (RouteFinder)

Thin index for humans working in this repo. Prefer linking one Doc at a time over dumping the whole `Docs/` tree.

## Layout

| Path | Role |
|------|------|
| `RouteFinder/` | Swift 6 SPM package (UI, fleet, routing, physics) |
| `RouteFinderApp.xcodeproj` | iOS / Mac app schemes |
| `web-dispatch/` | Vite + React LAN dispatch desk |
| `hosted-gateway/` | Optional Operator VPS gateway |
| `android-fleet-driver/` | Android C2 driver |
| `Docs/` | Specs, QA, verification — pull on demand |

## Tests (typical)

```bash
cd RouteFinder && swift test
cd web-dispatch && npm test
# UI smoke (simulator):
xcodebuild test -project RouteFinderApp.xcodeproj -scheme RouteFinderApp \
 -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
 -parallel-testing-enabled NO
```

## Hard rules

- **UI:** use `GlassmorphicModifiers` (`glassPanel`, `controlSheetStyle`, …).
- **Concurrency:** Swift 5.9+ / strict concurrency; value types + actors for shared mutable state; async/await for I/O.
- **Secrets:** never commit API keys, Bearer tokens, or screenshots that show them. Mask keys in product shots (`Docs/screenshots/`).
- **Scope:** leave unrelated simulation WIP unstaged unless asked to include it.
- **Commits:** follow existing commit message style; prefer issue → branch → PR for public history.

## Docs pointers

- Project writeup (NEA-style; Analysis + Design done → Implementation next): `Docs/project-writeup.md`
- Fleet LAN QA: `Docs/fleet-e2e-qa.md`
- Fleet API schema: `Docs/fleet-api-schema.json` (`FleetProxyDeskStatus` / `/v1/proxy/status` contract)
- Hosted desk deploy: `Docs/hosted-gateway-deployment.md` (EPIC-HOSTED-DESK Operator gateway)
- Getting started: `Docs/getting-started.md`
- Screenshots re-capture: `Docs/screenshots/README.md`
- Competitive / sweep: `Docs/ultimate-competitive-excellence-sweep.md` (Phase 3b surface matrix) + `Docs/engineering-test-matrix.md` + relevant `Docs/phase*` verification docs

## Tooling notes

| When | Prefer |
|------|--------|
| Library / framework API unsure | Current vendor docs |
| Competitive / web research | Public competitor pages + local research notes under ignored scrape dirs |
| web-dispatch UI check | Browser automation against the Vite desk |
| Hosted gateway / Workers | Cloudflare / Wrangler tooling already used in-repo |
| Product screenshots | `RouteFinderAppUITests/ProductScreenshotsUITests` → `Docs/screenshots/` |

IDE tips that already fit this repo: Swift, SweetPad, CodeLLDB, Oxc. Keep phase-verification markdown out of always-on editor rules.
