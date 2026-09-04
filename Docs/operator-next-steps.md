# Operator next steps (post system audit)

Simulator-first gate after code ship on `main`. CI UI tests are the official P0 Pass — physical iPhone is optional once before the first pilot email.

Last updated: 2026-09-04

---

## Phase 0 — This week (you)

### Block 1 — CI green on `main` (automatic)

**Status (2026-09-04): Pass** — latest `main` CI run succeeded (web-dispatch light-mode push and prior fleet/CORS jobs).

Confirm anytime: <https://github.com/thesnjk/RouteFinder/actions>

That is **P0 Pass**. No code action required from you for Block 1.

### Block 1b — Optional pre-pilot phone smoke (~10 min)

**Once** before the first pilot email if you want subjective/device confidence. Not required for CI Pass.

1. Real HeiGIT key → Settings → API Keys → **Save** → relaunch and confirm it sticks.
2. Listen for metric voice (“400 metres”); tweak Voice/rate in Settings.
3. Resize on Mac Device Hub — no parchment cube.
4. (Optional) Fleet Part B LAN if pitching dispatch — see Block 2.

**Pilot interim (until fleet ORS proxy is in use):** **you** paste ORS (and optional TomTom) keys onto pilot devices during setup. Hauliers should not be asked to create HeiGIT accounts.

### Block 2 — Fleet Part B (~30 min) **optional pre-fleet pilot**

Mac + iPhone on same Wi‑Fi. Full steps: [`fleet-e2e-qa.md`](fleet-e2e-qa.md) Part B. Part A smoke already runs in CI.

1. Mac: `cd RouteFinder && swift run RouteFinderFleetServer --port 8080 --ors-key "$ORS_API_KEY"`
2. Mac: Dispatch Console → org + vehicle → show **QR** / copy vehicle UUID
3. iPhone: Settings → Fleet & Dispatch → **Fleet setup wizard** (or Discover → Test → Scan QR / paste UUID)
4. Enable **HGV mode** before routing
5. Mac: Push trip → iPhone toast ~5 s → Find route → Rehearse
6. iPhone: Walkaround ≥1 defect → Save
7. Mac: Defect card + PDF on dispatch console

### Block 3 — Norfolk pilot outreach **(CI is green — do this now)**

1. Print [`pilot-fleet-pack.md`](pilot-fleet-pack.md)
2. Optional: Block 1b phone smoke
3. Send **3–5** variants from [`pilot-outreach.md`](pilot-outreach.md) (start with Alfie Adams #2)
4. Log date + outcome in the outreach target table
5. Log every **Android / Windows** objection in [`pilot-feedback-backlog.md`](pilot-feedback-backlog.md)

Pitch line (honest):

> UK HGV nav with physics rehearsal no other app has. Push trips from your office Mac or browser over Wi‑Fi — no per-seat CoPilot tax. We set everything up for you in the pilot.

Do **not** promise: live telematics map, hosted SaaS portal, CarPlay, Android Auto, full Android navigation, remote VU, or 24/7 support.

### Block 4 — Free legal checklist

Complete remaining free items in [`legal/operator-legal-checklist.md`](legal/operator-legal-checklist.md) (Ltd entity, trademark filing decision, solicitor quote). Required before paid pilots / App Store.

---

## Demo stack (local)

```bash
# Terminal A — fleet server (operator-paid ORS when key set)
cd /Users/admin/Developer/RouteFinder/RouteFinder
swift run RouteFinderFleetServer --port 8080 --ors-key "$ORS_API_KEY"

# Terminal B — web dispatch
cd /Users/admin/Developer/RouteFinder/web-dispatch
npm run dev
# open http://127.0.0.1:5173
```

Operator guides: [`getting-started.md`](getting-started.md) · [`fleet-setup-guide.md`](fleet-setup-guide.md) · [`web-dispatch-operator-guide.md`](web-dispatch-operator-guide.md)

---

## Agent follow-up (continuity + operator-paid APIs)

Shipped / shipping with this audit sprint:

- Fleet Setup Wizard + QR pair (Mac / iOS / web)
- Web dispatch v1.5 (onboarding, health, snapshots, map preview)
- Fleet server ORS proxy + client routing without customer HeiGIT keys
- Server-side metering + fair-use docs

**Still gated on pilots (do not build yet):**

- Full Android navigator (C2) — [`android-c2-gate.md`](android-c2-gate.md)
- Hosted multi-tenant portal / live telematics map / CarPlay production

Do not start Android C2 until the gate document says unlock (≥2 paying renewals blocked by Android).
