# Phase 1 — 30-minute device checklist (Mac + iPhone)

Complete this on **real hardware** after CI is green. Same Wi‑Fi for Mac and iPhone. Mark Pass/Fail in [`phase20-verification.md`](phase20-verification.md) C3–C9 and P49b-2.

Last updated: 2026-09-09

---

## Before you start (2 min)

- [ ] Mac and iPhone on the **same Wi‑Fi**
- [ ] Xcode: `RouteFinderApp` scheme → your iPhone (signed build)
- [ ] Terminal: `export ORS_API_KEY="your-heigit-key"` (operator key — not on driver phone)
- [ ] Optional: TomTom key in Settings on iPhone for C9 only

---

## A — Fleet server + dispatch (8 min)

**Terminal A (Mac):**

```bash
cd /Users/admin/Developer/RouteFinder/RouteFinder
swift run RouteFinderFleetServer --port 8080 --ors-key "$ORS_API_KEY"
```

Expect: `starting on 0.0.0.0:8080`, `ORS proxy enabled`.

**Mac app:** Open `RouteFinderApp.xcodeproj` → **RouteFinderMac** → Run → **Dispatch** window.

1. [ ] Bootstrap demo fleet (or create org + vehicle)
2. [ ] Vehicle picker shows **QR code** under selected vehicle
3. [ ] Note Mac LAN IP: System Settings → Network (e.g. `192.168.1.10`)

**Optional web dispatch (same Wi‑Fi):**

```bash
cd /Users/admin/Developer/RouteFinder/web-dispatch && npm run dev
```

4. [ ] Open http://127.0.0.1:5173 → Test /health → green Connected
5. [ ] Register vehicle → QR visible → Copy UUID works

---

## B — iPhone fleet wizard (7 min)

1. [ ] Launch **RouteFinderApp** on iPhone (delete+install optional for C1)
2. [ ] Sign in / accept Driver Terms → choose **HGV**
3. [ ] Settings → Fleet & Dispatch → **Open fleet setup wizard**
4. [ ] Enable remote server → **Discover on LAN** → pick Mac server (or paste `http://<mac-ip>:8080`)
5. [ ] **Test connection** → Connected
6. [ ] **Scan QR** from Mac/web dispatch (or paste vehicle UUID) → Save → Finish
7. [ ] **Do not** save a personal HeiGIT key if ORS proxy is on — orange cloud banner should **not** nag for API key

---

## C — Trip push + route (8 min)

**Mac Dispatch (or web):** Push 2-stop trip (e.g. Norwich → King's Lynn).

1. [ ] iPhone toast within ~5 s
2. [ ] **Find route** succeeds without driver ORS key (fleet proxy)
3. [ ] **Rehearse Route** completes; trip brief updates
4. [ ] **Start** navigation → voice gives metric distances (e.g. “400 metres”)

Mark **P49b-2 Fleet Part B** Pass/Fail in phase20.

---

## D — Physical QA scenarios C3–C9 (12 min)

| # | Steps | Pass? | Notes |
|---|--------|-------|-------|
| **C3** | Map menu → Walkaround → complete ≥1 zone with defect note → Save → Share PDF | | |
| **C4** | Settings → Navigation → Layby voice **on** → HGV route with layby ahead → hear voice once inside 5 km | | |
| **C5** | Settings → Fuel card provider → pick brand → route with fuel POI ahead → “Accepts your … card” banner | | |
| **C6** | Report closure on route (hazard sheet) → during nav see hazard-ahead banner + voice | | |
| **C7** | Route through OSM construction corridor → roadworks-ahead banner | | |
| **C8** | *(CI sim Pass)* Settings → API Usage + Legal Driver Terms — spot-check on device | | |
| **C9** | Save TomTom key in Settings → navigate live route → traffic/closure hazard ahead alert | | Requires TomTom key |

---

## E — Sign-off

1. [ ] Update [`phase20-verification.md`](phase20-verification.md) table: replace **Pending local** with **Pass** or **Fail** + one-line note per C3–C9
2. [ ] If any Fail: log in [`pilot-feedback-backlog.md`](pilot-feedback-backlog.md) and run Phase 1 agent fix loop

**Phase 1 exit gate:** All automated tests green + you marked C3–C9 and Fleet Part B on real hardware.

---

## Quick automated re-check (agent / CI)

```bash
cd /Users/admin/Developer/RouteFinder/RouteFinder
swift test
./Scripts/fleet-e2e-smoke.sh
cd ../web-dispatch && npm test && npm run build
```
