# Phase 1 — 30-minute device checklist (Mac + iPhone)

Complete this on **real hardware** after CI is green. Same Wi‑Fi for Mac and iPhone. Mark Pass/Fail in [`phase20-verification.md`](phase20-verification.md) C3–C9 and P49b-2.

Last updated: 2026-09-29

---

## Before you start (2 min)

- [ ] Mac and iPhone on the **same Wi‑Fi**
- [ ] Xcode: `RouteFinderApp` scheme → your iPhone (signed build)
- [ ] Terminal: `export ORS_API_KEY="your-heigit-key"` and `export FLEET_API_KEY="your-shared-secret"` (operator keys — not on driver phone as personal HeiGIT)
- [ ] Optional: TomTom key in Settings on iPhone for C9 only

---

## A — Fleet server + web-dispatch desk (8 min)

**Terminal A (Mac) — fleet server:**

```bash
cd /Users/admin/Developer/RouteFinder/RouteFinder
swift run RouteFinderFleetServer --port 8080 --ors-key "$ORS_API_KEY" --api-key "$FLEET_API_KEY"
```

Expect: `starting on 0.0.0.0:8080`, `ORS proxy enabled`.

**Terminal B — web-dispatch (primary desk):**

```bash
cd /Users/admin/Developer/RouteFinder/web-dispatch && npm run dev
```

1. [ ] Open http://127.0.0.1:5173 → health auto-checks → green **Connected** (paste Bearer = `$FLEET_API_KEY`; re-tap **Test /health** after URL/Bearer change)
2. [ ] **Bootstrap demo fleet** (Demo Haulage Ltd / Artic 1) — or create org + vehicle
3. [ ] Vehicle **QR** visible → Copy UUID works
4. [ ] Norwich → King's Lynn pre-filled; **Push trip** when vehicle selected
5. [ ] Optional: Mac **RouteFinderMac** for map simulation only (⇧⌘D opens web-dispatch). Legacy native Dispatch is Settings → Advanced only.

**Copy LAN for phone:** from web Connection / Mac Settings Copy LAN — share `http://<lan-ip>:8080` if Discover fails.

---

## B — iPhone fleet wizard (7 min)

1. [ ] Launch **RouteFinderApp** on iPhone (delete+install optional for C1)
2. [ ] Sign in / accept Driver Terms → choose **HGV**
3. [ ] Settings → Fleet & Dispatch → **Open fleet setup wizard** (or Driver setup → Pair with fleet)
4. [ ] Enable remote server → **Discover on LAN** → pick Mac server (or paste LAN URL from Mac **Copy LAN URL**)
5. [ ] **Test connection** → Connected; enter the same **Fleet API key** as `--api-key`
6. [ ] **Scan QR** from Mac/web dispatch (or paste vehicle UUID) → Save → Finish
7. [ ] **Do not** save a personal HeiGIT key if ORS proxy is on — orange cloud banner should **not** nag for API key

---

## C — Trip push + route (8 min)

**web-dispatch:** Push (Norwich → King's Lynn is the default corridor — Load optional reset).

1. [ ] iPhone toast within ~5 s
2. [ ] Route auto-loads or **Find route** succeeds without driver ORS key (fleet proxy)
3. [ ] **Rehearse Route** completes; trip brief updates
4. [ ] **Start** navigation → voice gives metric distances (e.g. “400 metres”)
5. [ ] web-dispatch roster / Last GPS updates after Start (or sim)

Mark **P49b-2 Fleet Part B** Pass/Fail in phase20 after **iPhone** walkaround → **web-dispatch** defect card (section D **C3** + Part B step 9 in [`fleet-e2e-qa.md`](fleet-e2e-qa.md)). Do not run Walkaround from Mac Settings — cab checklist is phone-only.

---

## D — Physical QA scenarios C3–C9 (12 min)

| # | Steps | Pass? | Notes |
|---|--------|-------|-------|
| **C3** | **On iPhone** (not Mac): map menu → Walkaround → mark ≥1 defect → optional photo → Save → Share PDF; **Mac Dispatch** then shows defect card / PDF | | |
| **C4** | Settings → Navigation → Layby voice **on** → HGV route with layby ahead → hear voice once inside 5 km | | |
| **C5** | Settings → Fuel card provider → pick brand → route with fuel POI ahead → “Accepts your … card” banner | | |
| **C6** | Report closure on route (hazard sheet) → during nav see hazard-ahead banner + voice | | |
| **C7** | Route through OSM construction corridor → roadworks-ahead banner | | |
| **C8** | *(CI sim Pass)* Settings → API Usage + Legal Driver Terms — spot-check on device | | |
| **C9** | Save TomTom key in Settings → navigate live route → traffic/closure hazard ahead alert | | Requires TomTom key on **iPhone**; else Skip |

---

## E — Sign-off

Paste to the agent (fill brackets), then update [`phase20-verification.md`](phase20-verification.md):

```text
Operator QA done. Update Docs/phase20-verification.md only:
C4 = [Pass/Fail/Skip + note],
C9 = [Pass/Fail/Skip + note],
Fleet Part B = [Pass/Fail + note].
```

1. [ ] Replace **Blocked** / **Pending local** with **Pass** / **Fail** / **Skip** + one-line note for C4, C9, Fleet Part B
2. [ ] If any Fail: log in [`pilot-feedback-backlog.md`](pilot-feedback-backlog.md) and run a scoped fix loop

**Phase 1 exit gate:** All automated tests green + you marked C4 / C9 / Fleet Part B on real hardware.

---

## Quick automated re-check (agent / CI)

```bash
cd /Users/admin/Developer/RouteFinder/RouteFinder
swift test
./Scripts/fleet-e2e-smoke.sh
cd ../web-dispatch && npm test && npm run build
```
