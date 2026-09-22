# Phase 4 — Platform parity verification

Engineering excellence track (`eng-p4-platform`). No legal/GTM.  
Last updated: 2026-09-18

**Goal:** Same fleet HTTP surface on LAN, web, Android, hosted — CarPlay production-ready on paid team; Android C2 MVP demoable; hosted gateway client pointer proven.

**Competitive edge:** vs Sygic CarPlay IAP — templates included once entitled; vs CoPilot Android — same `/v1/*` + ORS proxy as iOS; vs enterprise hosted — identical client config for LAN vs VPS.

---

## Automated gate

| Check | Command | Result |
|-------|---------|--------|
| Swift package tests | `cd RouteFinder && swift test` | **Pass** (2026-09-18) |
| CarPlayUITests (package) | `swift test --filter CarPlayUITests` | **Pass** (macOS stub; iOS factory tests compile under `#if os(iOS)`) |
| Hosted URL → connection kind | `swift test --filter httpsFleetURLInfersHostedConnectionKind` | **Pass** |
| Fleet Part A | `./Scripts/fleet-e2e-smoke.sh` | **Pass** 9/9 |
| Android unit + APK | `JAVA_HOME=…22 ./gradlew :app:testDebugUnitTest :app:assembleDebug` | **Pass** |
| Hosted gateway | `cd hosted-gateway && npm test && npm run typecheck` | **Pass** (8 tests) |
| Hosted local curl smoke | `PORT=18787` health / 401 / orgs / proxy status | **Pass** |
| Web-dispatch smoke | `cd web-dispatch && npm test` | **Pass** |
| iOS app simulator build | `xcodebuild build -project RouteFinderApp.xcodeproj -scheme RouteFinderApp -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO` | **Pass** (BUILD SUCCEEDED 2026-09-18) |

---

## CarPlay (`EPIC-CARPLAY-PROD`)

Full script: [`phase5-carplay-verification.md`](phase5-carplay-verification.md). Restore: [`carplay-weatherkit-restore.md`](carplay-weatherkit-restore.md).

| Check | Result | Owner |
|-------|--------|-------|
| Entitlements `carplay-maps` + `weatherkit` in `RouteFinderApp.entitlements` | **Pass** | Engineering |
| Package reference keys match (`RouteFinderIOS.entitlements`) | **Pass** | Engineering |
| `.routeLoaded` fleet handoff in `CarPlayNavigationCoordinator` | **Pass** (code) | Engineering |
| `CarPlayUITests` green in package CI | **Pass** | Engineering |
| Xcode CarPlay simulator session (I/O → External Displays → CarPlay) | **Pending local** | Operator |
| Physical head unit | **Pending local** | Operator |
| Paid-team signing (no provisioning errors) | **Pending local** | Operator |

**Engineering Pass:** entitlements + coordinator bootstrap + automated tests. Interactive CarPlay session remains operator device QA (same pattern as Phase 2 C1–C9).

---

## Android C2 (`EPIC-ANDROID-C2`)

Full script: [`phase6b-android-nav-verification.md`](phase6b-android-nav-verification.md). Gate split: [`android-c2-gate.md`](android-c2-gate.md).

| Check | Result | Owner |
|-------|--------|-------|
| Unit tests + assembleDebug | **Pass** (2026-09-18) | Engineering |
| Engineering parity gate (MVP shipped) | **Open / Pass** | Engineering |
| Product prioritization gate (≥2 renewals) | **LOCKED** | Product / Operator |
| Manual Norwich → King's Lynn via fleet proxy | **Pending local** | Operator |
| Fleet handoff + GPS snapshot on device | **Pending local** | Operator |

**JDK note:** use OpenJDK 17–22 (CI uses 17). OpenJDK 25 fails Gradle — see `android-fleet-driver/README.md`.

---

## Hosted gateway

Full checklist: [`phase7-hosted-verification.md`](phase7-hosted-verification.md). Deploy: [`hosted-gateway-deployment.md`](hosted-gateway-deployment.md).

| Check | Result | Owner |
|-------|--------|-------|
| `npm test` + typecheck | **Pass** | Engineering |
| Local curl `/health`, auth, `/v1/proxy/status` | **Pass** | Engineering |
| iOS HTTPS → `FleetConnectionKind.hosted` | **Pass** (unit test) | Engineering |
| Cellular driver + web-dispatch against VPS TLS | **Pending local** | Operator |
| Metering persistence across restart | **Pass** (vitest) | Engineering |

---

## Fail / Pending list

| Item | Status | Owner |
|------|--------|-------|
| CarPlay interactive simulator / head unit | Pending local | Operator |
| Android Norwich corridor device QA | Pending local | Operator |
| Hosted VPS TLS + cellular SSE smoke | Pending local | Operator |
| Paid Apple team CarPlay provisioning | Pending local | Operator |

None of the above block engineering Phase 4 automated gate.

---

## Phase 4 quality gate

- [x] CarPlay: engineering Pass documented (entitlements + tests + `.routeLoaded`); interactive session Pending local
- [x] Android: unit tests green + manual Norwich Pending local with owner
- [x] Hosted: `npm test` green + client pointer smoke (curl + unit test)
- [x] Regression: CI surface green locally (`swift test`, fleet smoke, web-dispatch, android, hosted-gateway)
- [x] No legal/GTM / plan-file edits; no new nav features

**Sign-off:** `eng-p4-platform` — **completed** 2026-09-18 (engineering automated gate).

---

## Related

- [`engineering-benchmark-2026-09.md`](engineering-benchmark-2026-09.md) epics `#3`–`#4`
- [`phase3-stranger-ux-verification.md`](phase3-stranger-ux-verification.md)
- [`getting-started.md`](getting-started.md)
