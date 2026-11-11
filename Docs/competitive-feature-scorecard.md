# Competitive Feature Scorecard — September 2026

Last updated: 2026-11-11 (Phase 7b P0 Pass CI; Midlands + DESK-LAYBY Done; residual HD / live £ / AA / CarPlay / VU / country PBF)

Scoring: **0** Absent · **1** Weak · **2** Parity · **3** Lead  
Personas: **OO** = UK owner-operator · **SF** = small fleet (2–20 vehicles)

RouteFinder scores from code inventory + Phase 20/26/27/30–44 + **Phase 8** + **Phase 6** + Ultimate HGV U12–U15 engineering verification + Oct 2026 sweep. Competitor scores from public sources only (`.firecrawl/`).

---

## Phase 8 before / after (incremental — not full parity)

| Capability | Before | After | Notes |
|---|---:|---:|---|
| Toll awareness | **0** | **2** | Named UK advisories + ORS avoid/replan; **not** live tariffs |
| Telematics display | **0** | **2** | CSV + fleet ingest → desk pins; **not** remote VU |
| Parking partners | **1** | **2** | TRAVIS/SNAP deep links; **not** booking |
| Offline UX | **2** | **2** | Same capability; region picker + progress (Midlands M1–M6 mid-corridor) |
| Lane guidance | **2** | **2**† | OSM tag expansion + nav refresh + late-OSM prepare TTS (iOS + Android); still below TomTom HD |

† Documented as ~2.5 internally for OSM refresh depth; scorecard stays integer **2** vs TomTom/Sygic **3**.

---

## Owner-operator weights

| Capability | Weight | RF | Sygic | TomTom HW | CoPilot 11 | Garmin | Notes |
|---|---:|---:|---:|---:|---:|---:|---|
| Constraint routing (L/W/H/hazmat) | 18% | **3** | 2 | 3 | 3 | 3 | RF ORS + offline hybrid |
| Offline UK maps | 12% | **2** | 3 | 3 | 2 | 3 | RF corridor packs (Norfolk / East Anglia / Midlands M1–M6) + post-find polyline prefetch (≤ East Anglia); residual = country-pack depth; Android offline gated |
| Physics rehearsal | 14% | **3**‡ | 0 | 0 | 0 | 0 | RF wedge; `spineSpeedLimitAcceleratesToMotorwayLimit` Pass (2026-11-09) |
| Layby / break intel | 12% | **3** | 1 | 2 | 2 | 2 | RF fused ranker + Break Now + TRAVIS/SNAP links (Ph8); CoPilot 11.4 parking icons — still **2** (booking ≠ RF $0) |
| LEZ compliance | 8% | **3** | 3 | 3 | 2 | 2 | RF 11 zones + ORS avoid (iOS rings; Android U15) |
| Lane guidance | 8% | **2** | 3 | 3 | 2 | 2 | RF OSM Overpass parity (cap 12 + STRAIGHT skip + 50 km arc iOS↔Android) + prepare TTS + which-lane PTT; residual = HD lane visuals |
| Plate → profile (UK) | 8% | **3** | 0 | 0 | 0 | 0 | RF RegCheck + DVLA |
| Crowd hazard / closure ahead | 5% | **2** | 1 | 1 | 0 | 0 | RF Ph33 + Ph36 TomTom live + Android report fuse + map pins + still-there confirm |
| UK toll awareness | 5% | **2** | 2 | 3 | 2 | 2 | RF named hints + avoid-before-commit + commit TTS + in-nav HUD + avoid-tolls PTT; TomTom live tariffs still lead |
| Telematics / tacho display | 5% | **2** | 1 | 1 | 2 | 1 | RF CSV + fleet ingest → desk pins + Can-I-drive week card; Samsara VU still leads |
| Price ($0 baseline) | 5% | **3** | 1 | 1 | 0 | 1 | Pilot £0 / post-pilot API-included desk subscription ([`pilot-fleet-pack.md`](pilot-fleet-pack.md)); not per-seat cloud portal; CoPilot quote-only |

**Weighted OO score (approx.):** RouteFinder **~2.56** · Sygic **~2.00** · TomTom **~2.20** · CoPilot **~1.80**  
(U15 LEZ ORS avoid lifts RF LEZ row 2→3; not full competitor parity — footnote.)

---

## Small-fleet weights

| Capability | Weight | RF | CoPilot AM | PTV | Samsara | Notes |
|---|---:|---:|---:|---:|---:|---|
| Dispatch push | 18% | **3** | 2 | 2 | 3 | RF SSE + native console + hosted gateway |
| Physics ETA to depot | 14% | **3** | 1 | 2 | 2 | RF wedge |
| Trip brief PDF | 12% | **3** | 1 | 2 | 2 | RF shipped |
| LAN / hosted sync | 14% | **3** | 0 | 1 | 0 | RF $0 LAN + Phase 7 hosted |
| Layby on trip | 10% | **3** | 2 | 1 | 0 | RF prediction + partner links |
| Constraint routing | 10% | **3** | 3 | 3 | 2 | Parity |
| Auth/TLS fleet server | 8% | **2** | 3 | 3 | 3 | RF API key + optional TLS; pilot-default `--api-key` + actionable 401 (not SSO/mTLS) |
| Telematics ingest (read-only) | 4% | **2** | 2 | 2 | 3 | CSV → POST ingest on iOS/Android; desk pins; not VU |
| Price | 10% | **3** | 0 | 0 | 0 | Pilot £0 / post-pilot API-included desk subscription ([`pilot-fleet-pack.md`](pilot-fleet-pack.md)); not per-seat cloud portal |

**Weighted SF score (approx.):** RouteFinder **~2.78** · CoPilot AM **~1.55** · PTV **~1.80** · Samsara **~1.70** (nav slice only)

---

## Gap ranking (Phase 26 decision — historical)

Formula: `(competitor best − RF) × persona weight × feasibility ($0, no CarPlay)`

| Rank | Gap | OO gap×wt | SF gap×wt | Feasibility | **Build?** |
|---:|---|---:|---:|---|---|
| 1 | Break Now UX | 0.15 | 0.05 | High | **Yes — Ph26** |
| 2 | LEZ v2 copy + coverage | 0.10 | 0.02 | High | **Yes — Ph26** |
| 3 | Lane voice + banner | 0.10 | 0.02 | High | **Yes — Ph26** |
| 4 | Fleet E2E hardening (docs) | 0.02 | 0.12 | Medium | **Done — Ph27c** |
| 5 | Map label i18n | 0.03 | 0.04 | Medium | **Done — Ph27b** |
| 6 | Driver onboarding sheet | 0.05 | 0.03 | High | **Done — Ph27a** |

**Phase 8 wave:** UK toll hints · telematics CSV/webhook stub · parking deep links · offline region progress · lane Overpass depth — **complete**. QA: [`phase8-parity-verification.md`](phase8-parity-verification.md).

---

## Engineering excellence — Phase 6 (performance + demo)

Engineering-only deltas (no GTM / pricing). Evidence: [`phase6-performance-verification.md`](phase6-performance-verification.md), [`demo-superiority-script.md`](demo-superiority-script.md).

| Capability | Before Ph6 | After Ph6 | Notes |
|---|---:|---:|---|
| Demo script (push → rehearse → pin → walkaround) | Doc scatter | **3** | One-take script with competitor callouts |
| Lane Overpass cost discipline | Cap shipped, unmeasured | **3** | Asserted ≤12 Overpass fetches / route find |
| Offline download progress correctness | UX present | **3** | Progress events == H3 cell count (tested) |
| Web dispatch map preview stability | Poll churn | **3** | Fingerprint skips timestamp-only updates |
| Fleet proxy 429 surfacing | Generic HTTP error | **3** | Explicit daily-cap copy on route + geocode (iOS / Android / web) |

Weighted OO/SF tables above are **unchanged** by Phase 6 (performance / honesty, not new capability rows).

---

## Ultimate HGV — predictive fuse & job brief (2026-09)

| Capability | iOS / macOS | Android C2 | Notes |
|---|---:|---:|---|
| Unified `RouteRiskAdvisory` fuse (kinetic / weather / hazard / roadworks / traffic) | **3** Lead | **3** (U11 + 2026-11 roadworks) | Primary HUD + voice dedup on Apple; Android fused banner + schedule/forecast/clearance + OSM `highway=construction` via fleet Overpass (`RoadworksAlongRouteClient`) |
| `FleetJobBrief` weight / ADR / auto-find on SSE push | **3** | **3** | Android ORS includes ADR→hazmat; time windows on status card (U11) |
| RegCheck on job intake (plate → dims) | **3** | **3** | Android RegCheck + optional DVLA VES fallback (operator key; weight/HGV class) |
| DVSA walkaround + defect photos + PDF | **3** | **3** (U12) | Android gallery attach + local PDF + richer snapshot handoff |
| 1–3h traffic/weather forecast advisories | **3** (U8 + U14 proxy) | **3** (U11 + U14) | Fleet TomTom/OpenWeather proxy — zero driver forecast keys on iOS + Android |
| Off-route / corridor clearance radar | **3** (U9 + U11-B2) | **3** (U14b) | Android: on-route Overpass + heading corridor when off-spine |
| LEZ / CAZ ORS `avoid_polygons` | **3** | **3** (U15) | Android `LezAvoidPolicy` mirrors iOS area + long-haul caps |
| HOS clock + layby ahead | **3** | **3** (WTD+fortnight) | Android Drive/Break/Off + weekly 56h + 10h ext + fortnight 90h gate + WTD ≥60h heads-up; both platforms have best-effort DDD/JSON importers (opaque binary DDD residual) |

† U12–U15 closed Android walkaround PDF, LEZ/HOS/layby advisory, fleet forecast/clearance proxy, off-route clearance, and ORS LEZ avoid. 2026-11: Android roadworks-in-fuse + corridor layby Overpass + ~5 km layby voice + Can-I-drive day/week + **duty-log** + **10h extension** + **WTD/fortnight** + **Lane Overpass parity** (cap 12 / STRAIGHT skip / 50 km). Residual: HD lane visuals; opaque binary DDD; LEZ circle envelopes; optional U16 shared boundary asset.

---

## Oct 2026 sweep note

Full re-scrape: [`ultimate-competitive-excellence-sweep.md`](ultimate-competitive-excellence-sweep.md).  
**CoPilot 11.4** (Aug 2026): Driver Assistant, street callouts, parking availability icons, AA polish, NA bumper-to-bumper length, US ELD HOS sync.  
**Scrape decision:** no OO/SF integer changes (~2.56 OO / ~2.78 SF).  
**Driver-first reopen (2026-10-12b):** previously “won’t chase” rows become **sequenced gaps** — see backlog in the sweep doc.

‡ Physics Lead is CI-honest; `spineSpeedLimitAcceleratesToMotorwayLimit` Pass (`EPIC-SIM-SPEEDLIMIT` Done 2026-11-09).

---

## Sequenced gaps (driver-first — was “intentional non-parity”)

Policy: ship anything that benefits the driver; sequence by impact, not permanent deferral. Full epic table: [`ultimate-competitive-excellence-sweep.md`](ultimate-competitive-excellence-sweep.md#driver-first-reopen--2026-10-12b).

| Capability | Best-in-class | RouteFinder today | Status / residual epic |
|---|---|---|---|
| Hands-free driver assistant | CoPilot 11.4 | Domain PTT: which-lane / avoid-tolls / layby / hazard / book parking / Can-I-drive day+week | **Shipped (MVP)** — residual: freer NLU / street-name depth (`EPIC-LANE-DEPTH`) |
| Parking availability UX | CoPilot 11.4 icons | Ranked layby green/amber/red map pins (iOS + Android) + occupancy taps + Break Now; Mac/web desk `predictedLayby` card + pin + Android snapshot publish | **Shipped (MVP)** — residual: live bay counts / partner occupancy feed |
| Parking booking | CoPilot + TRAVIS | Deep links + voice “book parking” entry | **Shipped (MVP)** — residual: native partner book API |
| CarPlay production | Sygic / CoPilot | Code ready; entitlements inactive | **Gated** `EPIC-CARPLAY-PROD` |
| Android Auto | CoPilot 11.4 | Not shipped | **Gated** `EPIC-ANDROID-AUTO` |
| Combo / bumper length + trailer count | CoPilot 11.4 (NA maps) | Cab + Mac/web desk trailer→ORS ladder (12 / 16.5 / 18.75 / 25.25 m); Constraint stays **3** | **Shipped (MVP)** |
| Lane HD / street callouts | TomTom / Sygic / CoPilot 11.4 | OSM Overpass parity (12 / STRAIGHT skip / 50 km) + sanitize street TTS/HUD/which-lane; residual HD visuals | **Shipped (MVP slice)** — Overpass parity Done; residual HD lane visuals (`EPIC-LANE-DEPTH`) |
| Toll tariff depth | PTV / TomTom | Named UK advisories + avoid/HUD/PTT + Mac/web desk corridor indicative £ | **Shipped (MVP slice)** — residual live operator tariffs (`EPIC-TOLL-DEPTH`) |
| Remote VU download | Samsara / Geotab | Advisory tacho + desk Can-I-drive week card; CSV stub | **Residual** `EPIC-VU-PARTNER` (legal VU download) |
| Legal LEZ cadastre | Sygic / TomTom | Simplified authored rings | **Residual** `EPIC-LEZ-CADASTRE` |
| Hosted multi-depot desk | CoPilot Account Manager | Named depot profiles; no billing UI | **Residual** `EPIC-HOSTED-DESK` |
| Per-seat API burn visibility | Enterprise fleet SaaS | On-device ledger + soft budgets (Ph45) | Keep ledger; expand when hosted seats ship |
