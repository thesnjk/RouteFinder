# Agent map (RouteFinder)

Thin index for Cursor agents. Prefer `@` specific Docs over dumping the whole tree.

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
- **Scope:** leave unrelated simulation WIP unstaged unless the user asks to include it.
- **Commits:** only when the user asks; follow existing commit message style.

## Docs pointers

- **Master session prompt (local-only, gitignored):** `@Docs/agent-master-prompt.md` — attach each chat; agent plans/executes; prints git commands — never commit/push
- Fleet LAN QA: `Docs/fleet-e2e-qa.md`
- Getting started: `Docs/getting-started.md`
- Screenshots re-capture: `Docs/screenshots/README.md`
- Competitive / sweep: `Docs/ultimate-competitive-excellence-sweep.md`

## Agent tooling (low context)

Prefer `@AGENTS.md` + `@Docs/<one file>` + `@path/to/file` over reading the whole Docs tree.

| When | Use |
|------|-----|
| Library / framework API unsure | Context7 plugin |
| Competitive / web research | Firecrawl plugin |
| web-dispatch UI check | Playwright plugin |
| Hosted gateway / Workers | Cloudflare plugin (already enabled) |
| Product screenshots | `RouteFinderAppUITests/ProductScreenshotsUITests` → `Docs/screenshots/` |

Extensions already expected: Swift, SweetPad, CodeLLDB, Oxc. Do not dump phase-verification markdown into always-on rules.
