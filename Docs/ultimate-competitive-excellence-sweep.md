# RouteFinder — Ultimate Competitive Excellence Sweep (reusable)

Authoritative reusable prompt for ICP excellence sweeps. Load this file at the start of each sweep run.

## Execution rules

- NO clarifying questions. Make decisive tradeoffs using HGV logistics best practice for a UK 5–15 truck ICP (iPhone-first, LAN/hosted dispatch).
- EXECUTIVE SELECTION: ship the most robust, idiomatic production solution (Swift 6 + concurrency, Kotlin Android, TypeScript web). Prefer small verified diffs over speculative rewrites.
- Do NOT edit this prompt / plan files unless the user asks.
- Do NOT re-implement work already marked Done in [`ultimate-hgv-platform-spec.md`](ultimate-hgv-platform-spec.md) (U2–U15) unless regression tests fail.
- Do NOT expand into non-goals without writing them as explicit deferred epics: multi-tenant SaaS billing UI, remote VU/telematics replacement, Android Auto, planet offline PBF, live toll tariff tables, historical traffic ML, WebSocket (SSE+poll stays until pilot evidence).
- After code changes: run the four gates from [`engineering-test-matrix.md`](engineering-test-matrix.md) (`swift test`; fleet-e2e-smoke 14/14; Android unit tests with JDK 17–22; web-dispatch `npm test`). Fix real failures; harden flakes (e.g. dedicated Hummingbird ports).
- Do **not** execute `git commit` or `git push` unless the user explicitly asks in that turn. Always **print** ready-to-paste ship commands in deliverable §7 after gates are green.

## Mission

Make RouteFinder the strongest sellable + portfolio-grade UK HGV driver+dispatch hub for small fleets: stranger-simple, demo-unbeatable in ≤2 minutes, honest against competitors, production-safe, and visually/technically impressive in a portfolio walkthrough.

Authoritative inventory first:

- [`ultimate-hgv-platform-spec.md`](ultimate-hgv-platform-spec.md)
- [`competitive-feature-scorecard.md`](competitive-feature-scorecard.md)
- [`competitive-gap-matrix.md`](competitive-gap-matrix.md)
- [`architecture.md`](architecture.md)
- [`demo-superiority-script.md`](demo-superiority-script.md)
- [`phase3-stranger-ux-verification.md`](phase3-stranger-ux-verification.md)
- [`phase20-verification.md`](phase20-verification.md)
- [`pilot-fleet-pack.md`](pilot-fleet-pack.md)
- [`getting-started.md`](getting-started.md) (“Do not promise” list)

## Competitive bar (win where we claim lead)

Beat or clearly widen lead vs:

1. Sygic / CoPilot / TomTom GO — physics rehearsal, LAN zero-config dispatch, DVSA walkaround→brief/PDF, fused predictive risk HUD, LEZ avoid, layby+HOS.
2. Samsara / Webfleet — for ICP only: embedded fleet server + web/macOS desk + ORS/forecast proxy (no driver API keys). Do not fake enterprise telematics.
3. Waze / Google — HGV constraints, ADR, CAZ/LEZ, clearance radar. Do not chase crowd scale.

Update scorecard/gap matrix only when capability truly moves.

## Sweep procedure (do all layers every run)

### 1) Architecture & contracts

- Trace desk→driver: web/macOS → FleetServer SSE/REST → iOS FleetDispatchCoordinator/applyJobIntake → Android JobIntakeHandler → predictive fuse → PDF/handoff.
- Find broken contracts, dead paths, View-layer HTTP, missing error/cap surfacing, proxy metering holes.
- Propose/fix only high-leverage gaps; keep SSE+poll ADR.

### 2) Product completeness for daily ops (pillars A–C)

- A One-touch dispatch: zero accept taps on C2; job brief weight/ADR/time windows; RegCheck on intake.
- B Predictive risk: kinetic + fuse + forecast + clearance + off-route; metering; voice/HUD dedupe.
- C Compliance: HOS/layby, walkaround photos/PDF, LEZ ORS avoid (iOS rings; Android LezAvoidPolicy). Note residual U16 shared LEZ geometry as optional only.
- Usability: every driver flow ≤ target taps in phase3 / demo script; remove dead clicks and confusing Settings.

### 3) Cross-platform parity (honest)

- iOS/macOS is gold standard. Android C2: close only true daily-ops gaps that block a mixed fleet demo. Product-gated items stay gated (Android Auto, offline tiles).
- Web dispatch: trip push, map preview stability, job brief fields, inspection visibility.

### 4) Quality, reliability, performance

- Flaky tests: isolate ports, waitForFleetServerReady, no PdfDocument on plain JVM.
- Performance: route find / Overpass / forecast / map chrome — measure or assert budgets already in phase6 docs; kill wasteful polling.
- Security hygiene: no secrets in repo; API keys Keychain/prefs; fleet API key/TLS paths documented.

### 5) Sellability & portfolio polish

- Ensure [`demo-superiority-script.md`](demo-superiority-script.md) path works end-to-end with clear “why we win” callouts.
- Stranger UX: pair fleet → find route without personal HeiGIT key; actionable failure copy (proxy 429 caps, Auth failed vs Offline, etc.).
- Portfolio: README/getting-started accuracy; architecture diagram freshness; one crisp “what it is / is not” narrative; no false CarPlay/SaaS claims.
- Legal/pilot honesty: align with getting-started “Do not promise” and pilot-fleet-pack pricing narrative.

### 6) Operator / device gates (document, don’t fake Pass)

- CarPlay: entitlements present; paid-team QA remains operator Pending in phase5/phase20.
- Physical C4/C9/Part B: leave Blocked/Pending unless real device evidence exists.

## Deliverable format each run

1. Verdict: sellable ICP readiness (% + one sentence).
2. Competitive deltas found (lead / trail / honesty risk).
3. Changes made (files + why) OR “no code; docs only.”
4. Tests run + results (four gates).
5. Top 5 next leverage items ranked by (competitor gap × ICP weight × feasibility), explicitly excluding non-goals unless pilot evidence appears.
6. Portfolio/demo readiness: Pass / Needs work (bullet list).
7. **Ship commands** (always print after gates are green; do **not** run unless the user asks):
   - Brief `git status` / `git diff --stat` summary of this run’s files
   - Ready-to-paste:

```bash
git add <paths-from-this-run>
git commit -m "$(cat <<'EOF'
<why-focused 1–2 sentence message>

EOF
)"
git push -u origin HEAD
```

Prefer fixing the highest-leverage defect or polish item that improves a live demo or a paying Desk LAN pilot this week. Iterate until gates are green.
