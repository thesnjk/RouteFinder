# Operator next steps (post Ph55–57)

Single checklist after code ship `606dff4d` on `main`. Agent cannot run physical device QA — **you** must execute these blocks and mark Pass/Fail in [`phase20-verification.md`](phase20-verification.md).

Last updated: 2026-08-30

---

## Block 1 — P0 device QA (~15 min) **DO THIS FIRST**

**When:** iPhone on USB, unlocked, Xcode destination = your iPhone (not Offline).

1. Delete RouteFinder from the iPhone.
2. Xcode → `RouteFinderApp.xcodeproj` → scheme **RouteFinderApp** → your iPhone → **Clean Build Folder** → **Run**.
3. Log in → **Driver Terms** → **Vehicle type: Car** → map tiles load (Retry / Use online map if needed).
4. ⋯ → **Settings** → **API Keys** → paste HeiGIT key → **Save API Key** → green confirmation → **Refresh Usage** → **Legal** → Done.
5. Orange cloud nag **gone**.
6. Bottom **Where to?** → London → Manchester → **Find Route** → badge **Car · HeiGIT ORS**.
7. **Start Simulation** → vehicle visible → toolbar **Route overview** → full route north-up; resize on Mac Device Hub — no parchment cube.
8. Optional: listen for metric voice (“400 metres”); tweak Voice/rate in Settings.
9. Edit phase20: **C1**, **C2**, **C8**, **P49b-P0**, **P57-7** → Pass or Fail (+ screenshot note if Fail).

**Stop here if Fail.** Share screenshots in chat for Ph58 fixes.

---

## Block 2 — Fleet Part B (~30 min) **only if Block 1 Pass**

Mac + iPhone on same Wi‑Fi. Full steps: [`fleet-e2e-qa.md`](fleet-e2e-qa.md) Part B.

1. Mac: `cd RouteFinder && swift run RouteFinderFleetServer --port 8080`
2. Mac: Dispatch Console → org + vehicle → copy vehicle UUID
3. iPhone: Settings → Fleet dispatch → LAN discover → Test → Save vehicle id
4. Enable **HGV mode** (⋯ menu) before routing
5. Mac: Push trip → iPhone toast ~5 s → Find route → Rehearse
6. iPhone: Walkaround ≥1 defect → Save
7. Mac: Defect card + PDF on dispatch console
8. Mark **P49b-2** Pass/Fail in phase20

---

## Block 3 — Pilot outreach **only if Blocks 1 + 2 Pass**

1. Print [`pilot-fleet-pack.md`](pilot-fleet-pack.md)
2. Send one variant from [`pilot-outreach.md`](pilot-outreach.md) (e.g. Alfie Adams #2)
3. Log date in outreach target table

---

## Agent follow-up (Ph58)

After you mark P0 Pass/Fail, agent implements tight fixes only for reported failures (cube, voice, route corridor, peek sheet). No new features until pilots start.
