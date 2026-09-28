# Operator next steps (post Phases 1–9 drafts)

Simulator-first gate after code ship on `main`. CI UI tests are the official P0 Pass — physical iPhone is optional once before the first pilot email.

Last updated: 2026-09-27

---

## Prerequisites before outreach

1. **CI green on `main`** — <https://github.com/thesnjk/RouteFinder/actions>
2. Product stages **1–8** complete (fleet proxy, stranger UX, dispatch, CarPlay when entitled, Android driver, hosted gateway, parity extras)
3. Phase 9 **drafts** in-repo: [`legal/`](legal/), [`pilot-fleet-pack.md`](pilot-fleet-pack.md), [`app-store-connect-metadata.md`](app-store-connect-metadata.md) — solicitor / hosting still **you**

---

## Block 1 — CI green on `main` (automatic)

Confirm anytime: <https://github.com/thesnjk/RouteFinder/actions>

That is **P0 Pass**. No code action required from you for Block 1.

### Block 1b — Optional pre-pilot phone smoke (~10 min)

**Once** before the first pilot email if you want subjective/device confidence.

1. Real HeiGIT key on fleet server (`--ors-key`) so drivers need no HeiGIT account — or paste keys only for single-device demos.
2. Listen for metric voice (“400 metres”); tweak Voice/rate in Settings.
3. Optional: spot-check [`phase8-parity-verification.md`](phase8-parity-verification.md) (toll advisory, TRAVIS link, offline progress).
4. Settings → Legal: Privacy / Terms links present (placeholder URLs until you host HTML).

---

## Block 2 — Fleet Part B (~30 min) **recommended before first meeting**

Mac + iPhone on same Wi‑Fi. Full steps: [`fleet-e2e-qa.md`](fleet-e2e-qa.md) Part B.

1. Mac: `cd RouteFinder && swift run RouteFinderFleetServer --port 8080 --ors-key "$ORS_API_KEY" --api-key "$FLEET_API_KEY"`
2. Paste the same `$FLEET_API_KEY` into Mac Settings (fleet API key), web Bearer (if used), and the driver fleet wizard
3. Mac: Dispatch Console → org + vehicle → show **QR** / copy vehicle UUID
4. iPhone: Settings → Fleet & Dispatch → **Fleet setup wizard** (or Discover → Test → Scan QR / paste UUID)
5. Enable **HGV mode** before routing
6. Mac: Push trip → iPhone toast ~5 s → Find route → Rehearse
7. iPhone: Walkaround ≥1 defect → Save
8. Mac: Defect card + PDF + optional snapshot pin on dispatch console

---

## Block 3 — Norfolk pilot outreach **(primary)**

1. Print [`pilot-fleet-pack.md`](pilot-fleet-pack.md) (agreement + **£39/mo** API-included pricing table)
2. Optional: Block 1b phone smoke
3. Send **3–5** Norfolk variants from [`pilot-outreach.md`](pilot-outreach.md) — start with **N1 J Medler** / **N2 Richardson**, not northern reserves
4. Log date + outcome in the outreach target table
5. Log every **Android / Windows** objection in [`pilot-feedback-backlog.md`](pilot-feedback-backlog.md)

Pitch line (honest):

> UK HGV nav with physics rehearsal. Push trips from your office Mac or browser over Wi‑Fi — no per-seat CoPilot tax. Free 60-day / 3-phone pilot; after that a small desk fee with routing API included. We set everything up for you.

**May mention:** dispatch map pin from trip snapshots, read-only partner telematics CSV, optional hosted gateway for remote depots, UK toll **hints**, Android driver app for mixed fleets.

**Do not promise:** continuous live telematics platform, TRAVIS booking commerce, toll tariff tables, legal VU download, 24/7 SLA, CarPlay (unless paid-team entitled build), Android Auto.

---

## Block 4 — Legal checklist (you)

Complete [`legal/operator-legal-checklist.md`](legal/operator-legal-checklist.md): Ltd entity, trademark filing decision, solicitor review, host [`legal/site/`](legal/site/) HTML, App Store Connect URLs. Required before **paid** pilots / App Store. Free pilots may start with signed pilot agreement + in-app Driver Terms while solicitor review is booked.

Verification checklist: [`phase9-legal-gtm-verification.md`](phase9-legal-gtm-verification.md).

---

## Demo stack (local)

```bash
# Terminal A — fleet server (operator-paid ORS + pilot shared secret)
export ORS_API_KEY="your-heigit-key"
export FLEET_API_KEY="your-shared-secret"
cd RouteFinder
swift run RouteFinderFleetServer --port 8080 --ors-key "$ORS_API_KEY" --api-key "$FLEET_API_KEY"
# Paste the same $FLEET_API_KEY into Mac Settings / web Bearer / driver wizard

# Terminal B — web dispatch
cd web-dispatch
npm run dev
# open http://127.0.0.1:5173
```

Operator guides: [`getting-started.md`](getting-started.md) · [`fleet-setup-guide.md`](fleet-setup-guide.md) · [`web-dispatch-operator-guide.md`](web-dispatch-operator-guide.md) · [`hosted-gateway-deployment.md`](hosted-gateway-deployment.md)
