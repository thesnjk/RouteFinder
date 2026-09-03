# Pilot feedback engineering backlog

Ranked backlog filled **after** week-2 pilot feedback. Do not pre-build speculative features (hosted portal, Valhalla, live telematics) until evidence lands here.

Last updated: 2026-09-03

---

## How to use

1. Collect forms from [`pilot-fleet-pack.md`](pilot-fleet-pack.md) §4.
2. File each report as a row below (one row per distinct issue).
3. Priority = **pilot severity × frequency × unblock-for-renewal**.
4. Ship smallest fix; retest with the reporting fleet.
5. Log **Android drivers** / **Windows office** objections here immediately — they gate Android C1 and web dispatch priority (see [`android-c2-gate.md`](android-c2-gate.md)).

---

## Decision matrix (from GTM plan)

| If pilots say… | Build | Avoid |
|---|---|---|
| Need trucks on a map | Periodic location on `FleetTripSnapshot` + dispatch pin | Full telematics platform |
| Work from home, not office LAN | TLS + VPN guide; **then** minimal hosted relay if still blocked | React portal day one |
| Office is Windows / need browser dispatch | Finish [`../web-dispatch/`](../web-dispatch/) LAN console | Hosted multi-tenant SaaS |
| Drivers are on Android | Android C1 fleet receive client | Full Android navigator before ≥2 renewal blockers |
| ORS quota anxiety | Tune `APIUsageLedger` budgets; offline pack guide | Valhalla migration |
| Routing under a bridge | Log, reproduce, harden restriction announcements | Blame ORS without data |
| Want App Store / paid keys | Revisit owner-op pricing after 2+ paying signals | Raising price as a “trust signal” alone |

---

## Open items (fill after pilots)

| ID | Pilot | Report date | Summary | Severity | Priority | Status | Notes |
|---|---|---|---|---|---|---|---|
| — | — | — | *No reports yet — waiting on outreach* | — | — | Blocked on pilots | See [`pilot-outreach.md`](pilot-outreach.md) |

### Platform objections (Android / Windows)

| ID | Pilot | Report date | Summary | Severity | Priority | Status | Notes |
|---|---|---|---|---|---|---|---|
| — | — | — | *None yet — log every Android/Windows objection* | — | — | Open | Unlocks C1 / web priority |

---

## Explicitly deferred until evidence

| Item | Why deferred |
|---|---|
| Hosted multi-tenant SaaS portal | Native + LAN web dispatch first; hosted only if ≥2 pilots need remote |
| Full Android navigator (C2) | Gate: [`android-c2-gate.md`](android-c2-gate.md) — ≥2 paying renewals blocked by Android |
| Self-hosted Valhalla/GraphHopper | ORS + offline + metering enough for ≤3 pilots |
| Continuous live location streaming | Snapshot ping only if F9 demanded by ≥2 fleets |
| Custom OS / MDM kiosk | Ops after paying customers |
| Mass ads | B2B haulage = referrals |
| Further `RouteViewModel` decomposition | Ph51/52 done; stop until pilot bugs |

## In progress (scaffolded 2026-09-03)

| Item | Path | Notes |
|---|---|---|
| LAN web dispatch console | [`../web-dispatch/`](../web-dispatch/) | Thin client over existing fleet REST/SSE |
| Android C1 fleet driver | [`../android-fleet-driver/`](../android-fleet-driver/) | Trip receive + snapshot; not full nav |

---

## Pricing signals log

| Date | Pilot | Willing to pay? | Suggested model | Notes |
|---|---|---|---|---|
| | | | e.g. £29–£49/mo desk | |

Indicative fleet wedge (post-pilot): per dispatch desk / ≤10 vehicles on LAN. Owner-op App Store pricing deferred.
