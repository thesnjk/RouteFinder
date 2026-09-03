# Operator next steps (post Ph55–57)

Simulator-first gate after code ship on `main`. CI UI tests are the official P0 Pass — physical iPhone is optional once before the first pilot email.

Last updated: 2026-09-03

---

## Block 1 — CI green on `main` (automatic)

No manual action. Every push/PR runs:

- `swift test` + fleet E2E smoke (Part A)
- `RouteFinderAppUITests` on iOS Simulator (≥12 cases covering P0)

Confirm the latest `main` GitHub Actions `ios` job is green. That is **P0 Pass**.

P0 sim coverage includes: cold launch, vehicle Car/HGV onboarding, cloud banner hidden with key, peek bar, route profile badge, Start → Stop, Route Overview, active route chip, Settings API Usage + Legal Driver Terms, walkaround entry (HGV).

---

## Block 1b — Optional pre-pilot phone smoke (~10 min)

**Once** before the first pilot email if you want subjective/device confidence. Not required for CI Pass.

1. Real HeiGIT key → Save API Key → Keychain persists across relaunch.
2. Listen for metric voice (“400 metres”); tweak Voice/rate in Settings.
3. Resize on Mac Device Hub — no parchment cube.
4. (Optional) Fleet Part B LAN if pitching dispatch — see Block 2.

---

## Block 2 — Fleet Part B (~30 min) **optional pre-fleet pilot**

Mac + iPhone on same Wi‑Fi. Full steps: [`fleet-e2e-qa.md`](fleet-e2e-qa.md) Part B. Part A smoke already runs in CI.

1. Mac: `cd RouteFinder && swift run RouteFinderFleetServer --port 8080`
2. Mac: Dispatch Console → org + vehicle → copy vehicle UUID
3. iPhone: Settings → Fleet dispatch → LAN discover → Test → Save vehicle id
4. Enable **HGV mode** before routing
5. Mac: Push trip → iPhone toast ~5 s → Find route → Rehearse
6. iPhone: Walkaround ≥1 defect → Save
7. Mac: Defect card + PDF on dispatch console
8. Mark **P49b-2** Part B note in phase20 if run

---

## Block 3 — Pilot outreach **when Block 1 (CI) is green**

1. Print [`pilot-fleet-pack.md`](pilot-fleet-pack.md)
2. Optional: Block 1b phone smoke
3. Send one variant from [`pilot-outreach.md`](pilot-outreach.md) (e.g. Alfie Adams #2)
4. Log date in outreach target table

---

## Agent follow-up (Ph58)

If CI fails or Block 1b reports a concrete regression (cube, voice, route corridor, peek sheet), agent implements tight fixes only. No new features until pilots start.
