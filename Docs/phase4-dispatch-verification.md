# Phase 4 — Dispatch console verification (Mac + iPhone + web)

End-to-end check for geocoded web push, driver GPS snapshots, live pins, and fleet health pills.

Last updated: 2026-09-10

---

## Prep (5 min)

Same Wi‑Fi for Mac, office PC/browser, and iPhone. Terminal on the Mac:

```bash
export ORS_API_KEY="your-heigit-key"
cd /Users/admin/Developer/RouteFinder/RouteFinder
swift run RouteFinderFleetServer --port 8080 --ors-key "$ORS_API_KEY"
```

Confirm ORS proxy is enabled in the server log.

---

## Web (10 min)

1. `cd /Users/admin/Developer/RouteFinder/web-dispatch && npm run dev -- --host`
2. Office PC or Mac browser → `http://<mac-ip>:5173`
3. Set base URL to `http://<mac-ip>:8080` (or `/fleet` on the same Mac)
4. **Test connection** → green **Connected** (health + auth). Wrong `--api-key` → red **Auth failed** (not Offline) on Mac Dispatch pill **and** fleet setup wizard status.
5. Origin: type `Norwich` → pick suggestion → coords resolve
6. Destination: type `King's Lynn` → pick suggestion
7. Create org / register vehicle if needed; show QR to the driver
8. **Push trip** → map shows A/B at geocoded positions (not hardcoded demo defaults)

---

## Mac dispatch (5 min)

1. RouteFinderMac → **Dispatch** console
2. Fleet server health pill = **Connected** (or **Local disk** if not using remote store). **Auth failed** = API key mismatch; **Offline** = server/LAN down.
3. Select the same vehicle; active trip visible; map shows stop pins

---

## iPhone (10 min)

1. Pair via fleet setup wizard (no local ORS key if proxy is on)
2. Toast **New dispatch received — loading route…** → stops + route auto-load (zero-tap) → Start navigation **or** simulation
3. Wait ~30 s for a GPS snapshot publish (periodic ~20 s)

---

## Verify live pin (5 min)

1. Mac Dispatch map: **vehicle pin** appears / updates near the driver
2. Mac **DispatchStatusPanel**: **Last position** row with recent relative time (stale warning if &gt; 60 s)
3. Web **Driver snapshot** panel: **Last GPS** timestamp updates; map shows distinct driver marker
4. Optional Android C1: grant location (legacy C1 Accept / publish snapshot if using home screen) → same Last GPS on Mac/web within ~60 s. C2 navigator uses zero-tap SSE intake — no Accept tap.

---

## Pass criteria

| Check | Pass |
|-------|------|
| Geocoded web push | Stops land on Pelias coordinates, not Norwich/KL hardcodes unless chosen |
| Health pill | Green when Connected; red **Auth failed** for key mismatch; red **Offline** when server stopped |
| Driver pin | Visible on Mac + web within 60 s of iPhone nav/sim with location |
| Last position | Relative time updates on Mac status panel |

Operator hosting / TLS: [`web-dispatch-operator-guide.md`](web-dispatch-operator-guide.md).
