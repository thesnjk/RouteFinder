# Pilot feedback engineering backlog

Ranked backlog filled **after** week-2 pilot feedback. Do not pre-build speculative features (hosted portal, Valhalla, live telematics) until evidence lands here.

Last updated: 2026-08-29 (template — no pilot reports yet)

---

## How to use

1. Collect forms from [`pilot-fleet-pack.md`](pilot-fleet-pack.md) §4.
2. File each report as a row below (one row per distinct issue).
3. Priority = **pilot severity × frequency × unblock-for-renewal**.
4. Ship smallest fix; retest with the reporting fleet.

---

## Decision matrix (from GTM plan)

| If pilots say… | Build | Avoid |
|---|---|---|
| Need trucks on a map | Periodic location on `FleetTripSnapshot` + dispatch pin | Full telematics platform |
| Work from home, not office LAN | TLS + VPN guide; **then** minimal hosted relay if still blocked | React portal day one |
| ORS quota anxiety | Tune `APIUsageLedger` budgets; offline pack guide | Valhalla migration |
| Routing under a bridge | Log, reproduce, harden restriction announcements | Blame ORS without data |
| Want App Store / paid keys | Revisit owner-op pricing after 2+ paying signals | Raising price as a “trust signal” alone |

---

## Open items (fill after pilots)

| ID | Pilot | Report date | Summary | Severity | Priority | Status | Notes |
|---|---|---|---|---|---|---|---|
| — | — | — | *No reports yet — waiting on outreach* | — | — | Blocked on pilots | See [`pilot-outreach.md`](pilot-outreach.md) |

---

## Explicitly deferred until evidence

| Item | Why deferred |
|---|---|
| React/Next.js fleet web dashboard | Native dispatch + HTTP/SSE shipped |
| Self-hosted Valhalla/GraphHopper | ORS + offline + metering enough for ≤3 pilots |
| Continuous live location streaming | Snapshot ping only if F9 demanded by ≥2 fleets |
| Custom OS / MDM kiosk | Ops after paying customers |
| Mass ads | B2B haulage = referrals |
| Further `RouteViewModel` decomposition | Ph51/52 done; stop until pilot bugs |

---

## Pricing signals log

| Date | Pilot | Willing to pay? | Suggested model | Notes |
|---|---|---|---|---|
| | | | e.g. £29–£49/mo desk | |

Indicative fleet wedge (post-pilot): per dispatch desk / ≤10 vehicles on LAN. Owner-op App Store pricing deferred.
