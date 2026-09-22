# Demo superiority script (≈2 minutes)

Engineering excellence Phase 6. One-take demo for UK small-fleet ICP.  
Last updated: 2026-09-19

**Audience:** Operator or engineer who has never written this code.  
**Outcome:** Push → Rehearse → map pin → walkaround defect visible on dispatch — without a cloud seat portal.

---

## Prep (not timed — ~3 min)

1. Same Wi‑Fi for Mac + driver phone (or simulator).
2. Terminal:

```bash
export ORS_API_KEY="your-heigit-key"
cd /Users/admin/Developer/RouteFinder/RouteFinder
swift run RouteFinderFleetServer --port 8080 --ors-key "$ORS_API_KEY"
```

3. Confirm `GET http://<mac-ip>:8080/v1/proxy/status` shows `orsConfigured: true`.
4. Open **Mac Dispatch** or **web-dispatch** pointed at the fleet URL; create org + vehicle; show QR.
5. Driver app: Pair with fleet (no personal HeiGIT key) — see [`getting-started.md`](getting-started.md) / [`phase3-stranger-ux-verification.md`](phase3-stranger-ux-verification.md).

---

## Timed script (target ≤2:00)

| Clock | Action | Pass look |
|------:|--------|-----------|
| 0:00 | Dispatch: set origin **Norwich**, destination **King's Lynn** (geocode) → **Push trip** | Trip leaves draft |
| 0:15 | Driver: toast **Trip received** (SSE) | Toast **&lt;10 s** after push |
| 0:25 | Driver: route auto-loads or **Find route** | Polyline + ETA; no API-key nag |
| 0:40 | Driver: **Rehearse** | Physics ETA appears (may differ from ORS) |
| 1:00 | Driver: **Start** (or keep sim) so GPS snapshot flows | Mac/web **Last GPS** / driver pin updates within ~60 s |
| 1:20 | Confirm map preview includes driver pin | Web `TripMapPreview` / Mac `DispatchMapDetailView` |
| 1:35 | Driver: **Walkaround** → note ≥1 defect → save | Inspection on trip brief |
| 1:50 | Dispatch: defect card / inspection summary visible | No third-party portal |

**Stop** when inspection is visible on the desk.

---

## Competitor callouts (engineering honesty)

| Step | vs market |
|------|-----------|
| Push + LAN desk | **vs CoPilot Account Manager** — no per-seat cloud portal; same Wi‑Fi + SSE |
| Find route without driver key | **vs Sygic / consumer truck apps** — operator-paid ORS proxy |
| Rehearse | **vs CoPilot / Sygic / TomTom / Garmin phone nav** — pre-trip kinetic ETA absent there |
| Snapshot pin | **vs Samsara-class telematics** — periodic honest pin, not live VU map |
| Walkaround → desk | **vs fleet SaaS compliance portals** — PDF/summary on native/web dispatch without extra product |

Do **not** claim TomTom HD lanes, toll tariffs, or remote VU download.

---

## Failure recovery

| Symptom | Check |
|---------|-------|
| No toast | Fleet URL, vehicle UUID, same LAN; `fleet-e2e-smoke.sh` |
| API key banner | `usesFleetORSProxy` / remote fleet + `--ors-key` |
| No GPS pin | Snapshot PUT with lat/lon; see Phase 5 E2E GPS asserts |
| Map flicker every 5 s (web) | Phase 6 fingerprint — rebuild web-dispatch |

---

## Related

- [`phase1-device-checklist.md`](phase1-device-checklist.md)
- [`fleet-e2e-qa.md`](fleet-e2e-qa.md)
- [`engineering-test-matrix.md`](engineering-test-matrix.md)
- [`phase6-performance-verification.md`](phase6-performance-verification.md)
