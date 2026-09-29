# Demo superiority script (≈2 minutes)

Engineering excellence Phase 6. One-take demo for UK small-fleet ICP.  
Last updated: 2026-09-27

**Audience:** Operator or engineer who has never written this code.  
**Outcome:** Push → Rehearse → map pin → walkaround defect visible on dispatch — without a cloud seat portal.  
**Driver surface:** Depot **cab phone** (or simulator) — CarPlay / Android Auto not part of this demo.

---

## Prep (not timed — ~3 min)

1. Same Wi‑Fi for Mac + cab phone (or simulator).
2. Terminal:

```bash
export ORS_API_KEY="your-heigit-key"
export FLEET_API_KEY="your-shared-secret"
# From the repo root (clone), enter the Swift package directory:
cd RouteFinder
swift run RouteFinderFleetServer --port 8080 --ors-key "$ORS_API_KEY" --api-key "$FLEET_API_KEY"
```

Paste the **same** `$FLEET_API_KEY` into Dispatch **Save fleet API key** (or Mac Settings), web-dispatch Bearer token, and the driver fleet wizard. Recommended for every 5–15 truck LAN pilots.

Optional (only when demoing **forecast fuse** on drivers): `--tomtom-key` / `TOMTOM_API_KEY` and `--openweather-key` / `OPENWEATHER_API_KEY`. iOS and Android both consume these via the fleet proxy — drivers need no personal TomTom/OpenWeather keys. Not required for the ≤2-minute core path. Clearance radar Overpass also goes through the same fleet proxy when the cab is paired (meters 5–15 phones through one Mac).

3. Confirm Mac Dispatch **Fleet proxy** panel (or web Connection) shows ORS on — or `GET http://<mac-ip>:8080/v1/proxy/status` with `orsConfigured: true`.
4. Open **Mac Dispatch** or **web-dispatch** pointed at the fleet URL; **Bootstrap demo fleet** (or create org + vehicle); show QR.
5. Driver app: Pair with fleet (no personal HeiGIT key) — see [`getting-started.md`](getting-started.md) / [`phase3-stranger-ux-verification.md`](phase3-stranger-ux-verification.md).

---

## Timed script (target ≤2:00)

| Clock | Action | Pass look |
|------:|--------|-----------|
| 0:00 | Dispatch: **Push trip** (web opens with Norwich→King's Lynn pre-filled; Mac same default — Load optional reset) | Trip leaves draft |
| 0:15 | Driver: toast **Trip received** (SSE) | Toast **&lt;10 s** after push |
| 0:25 | Driver: route auto-loads or **Find route** | Polyline + ETA; no API-key nag |
| 0:40 | Driver: **Rehearse** | Physics ETA appears (may differ from ORS) |
| 1:00 | Driver: **Start** (or keep sim) so GPS snapshot flows | Mac/web **Last GPS** / driver pin updates within ~60 s |
| 1:10 | Dispatch: glance **Fleet roster** (Mac or web) | Status / physics ETA / GPS age row; click selects vehicle |
| 1:20 | Confirm map preview | **Yard pins** for every cab with GPS + selected truck corridor / highlight (web MapLibre ORS corridor; Mac `DispatchMapDetailView` stop polyline + yard pins) |
| 1:35 | Driver: **Walkaround** → note ≥1 defect → save | Inspection on trip brief |
| 1:50 | Dispatch: defect card / inspection summary visible | Mac `DispatchStatusPanel` **or** web Driver snapshot orange card (+ PDF download for iOS **and** Android walkaround — capped `inspectionReportPDFBase64`); no third-party portal |

**Stop** when inspection is visible on the desk.

---

## Competitor callouts (engineering honesty)

| Step | vs market |
|------|-----------|
| Push + LAN desk | **vs CoPilot Account Manager** — no per-seat cloud portal; same Wi‑Fi + SSE |
| Find route without driver key | **vs Sygic / consumer truck apps** — operator-paid ORS proxy |
| Rehearse | **vs CoPilot / Sygic / TomTom / Garmin phone nav** — pre-trip kinetic ETA absent there |
| Snapshot pin | **vs Samsara-class telematics** — periodic honest pin(s) on desk map (Mac + web yard pins), not live VU |
| Walkaround → desk | **vs fleet SaaS compliance portals** — PDF/summary on native/web dispatch without extra product |

Do **not** claim TomTom HD lanes, toll tariffs, or remote VU download.

---

## Failure recovery

| Symptom | Check |
|---------|-------|
| No toast | Fleet URL, vehicle UUID, same LAN; `fleet-e2e-smoke.sh` |
| API key banner | `usesFleetORSProxy` / remote fleet + `--ors-key` |
| HTTP 401 on desk push / catalog | Missing or mismatched fleet API key — paste the same `--api-key` into Dispatch **Save fleet API key** (or Mac Settings) / web Bearer / driver wizard |
| Office PC cannot reach Mac | Copy LAN fleet URL from **Dispatch** toolbar (or Office PC guide / Dispatcher onboarding); not `127.0.0.1`; same Wi‑Fi |
| No GPS pin | Snapshot PUT with lat/lon; see Phase 5 E2E GPS asserts |
| Map flicker every 5 s (web) | Phase 6 fingerprint — rebuild web-dispatch |
| Cap / HTTP 429 on Find route or desk geocode | Operator-paid proxy daily budget exhausted — raise caps or wait until tomorrow; glance Mac **Fleet proxy** or web Connection (**N left** / near-cap warning); curl `/v1/proxy/status` optional; iOS `RouteFailureMapper` / Android `FleetProxyErrorMapper` / web `fleetProxyUserMessage` show actionable copy |

---

## Appendix A — LEZ avoid (~45 s, driver Mac / iPhone)

Optional beat **after** the core ≤2:00 script (or in a portfolio walkthrough). Does **not** replace Norwich → King's Lynn.

Use a **≤140 km** corridor so ORS `avoid_polygons` actually fire. Hauls beyond that (e.g. Glasgow → Norwich) intentionally omit all LEZ avoids (ORS 2004 guard). London ULEZ remains **advisory / announcement-only** — its authored ring exceeds the ORS area cap.

| Clock | Action | Pass look |
|------:|--------|-----------|
| +0:00 | Driver Route Search: origin **Walsall**, destination **Solihull** | Both resolved |
| +0:10 | Vehicle emission class **non-compliant** for Birmingham CAZ (e.g. Euro 4); Settings **LEZ avoid** **on** | Restriction / LEZ toggle armed |
| +0:20 | **Find Route** (fleet ORS proxy or operator key) | Banner *Avoiding Birmingham CAZ…* (or equivalent `RestrictionZoneBanner`); polyline **skirts** the Birmingham CAZ envelope (not through the catalog center) |

**Why we win vs Sygic / TomTom / CoPilot:** HGV LEZ avoid on the **cab phone** with operator-paid routing — no per-driver HeiGIT key when fleet proxy is up. Do **not** claim legal cadastral LEZ geometry (authored rings / envelopes).

---

## Appendix B — LEZ avoid on Android C2 (~45 s)

Optional beat **after** the core ≤2:00 script (or paired with Appendix A in a mixed-fleet portfolio walkthrough). Does **not** replace Norwich → King's Lynn. Requires fleet server with `--ors-key` + `--api-key` and Android paired via the fleet wizard (same secret — no personal HeiGIT key).

Same corridor rules as Appendix A (≤140 km; London ULEZ area-capped).

| Clock | Action | Pass look |
|------:|--------|-----------|
| +0:00 | Android nav map: origin **Walsall**, destination **Solihull** (Pelias via fleet proxy) | Both resolved |
| +0:10 | Set **Euro class (LEZ)** to **Euro 4** (non-compliant for Birmingham CAZ); keep LEZ avoid **on** (default in prefs) | Euro class armed; avoid enabled |
| +0:20 | **Find route** | Advisory / avoiding copy for **Birmingham CAZ** (`UkLezCatalog`); no HeiGIT key prompt; polyline skirts CAZ envelope when `LezAvoidPolicy` sends under-cap rings |

**Why we win vs Sygic / TomTom / CoPilot:** HGV LEZ advisory + ORS avoid on an **Android cab phone** via the operator-paid fleet proxy — no per-driver HeiGIT key. Do **not** claim legal cadastral LEZ geometry. LEZ corridor story is on the **driver** app — not the web desk map. For the iOS Birmingham CAZ beat, use Appendix A.

---

## Related

- [`phase1-device-checklist.md`](phase1-device-checklist.md)
- [`fleet-e2e-qa.md`](fleet-e2e-qa.md)
- [`engineering-test-matrix.md`](engineering-test-matrix.md)
- [`phase6-performance-verification.md`](phase6-performance-verification.md)
- [`phase6b-android-nav-verification.md`](phase6b-android-nav-verification.md)
