# Pilot outreach — local fleet managers

Operator-run playbook for booking **3–5** small independent haulage/courier meetings (5–15 trucks), within driving distance for LAN demos.

**Operator base: Norfolk / East Anglia.** Prefer door visits and coffee demos within ~45 minutes. Northern England names stay as remote-email reserves only.

Last updated: 2026-09-03

---

## Prerequisites (do not pitch until done)

1. **CI green on `main`** (simulator P0) — [`phase20-verification.md`](phase20-verification.md) P49b-P0 / P57-7 **Pass (CI sim)**, or [`operator-next-steps.md`](operator-next-steps.md) Block 1
2. Optional: Block 1b phone smoke (voice, Device Hub resize, real Keychain) before first meeting
3. Print [`pilot-fleet-pack.md`](pilot-fleet-pack.md) (agreement + feedback form)
4. Fleet Part B LAN dry-run only if pitching dispatch console on site

---

## Target list — Norfolk / East Anglia (primary)

| # | Company | Contact | Size | Date contacted | Meeting | Outcome |
|---|---|---|---|---|---|---|
| 1 | J Medler Haulage (Norwich outskirts) | [jmedlerhaulagenorwich.co.uk](https://jmedlerhaulagenorwich.co.uk/) · door / site | ~12 HGV | 2026-09-03 | | site opened — send N1 via contact form / door |
| 2 | Richardson Truck Services (Bradenham, IP25) | 07901 774767 · [richardson-truck-services.co.uk](https://www.richardson-truck-services.co.uk/) | Family haulage + workshop | 2026-09-03 | | dialer opened — **call** then set Outcome to spoke / voicemail |
| 3 | Gary Chapman & Son (Norfolk) | [garychapmanandson.co.uk](https://www.garychapmanandson.co.uk/) · door / site | Family plant / haulage | | | |
| 4 | T.G. Askew (Bressingham, Norfolk) | [tgaskew.co.uk](https://www.tgaskew.co.uk/) · door / site | Family bulk haulage, FORS | | | |
| 5 | W's Transport (East Dereham) | Research before call (confirm still trading) | ~6 lorries historically | | | |

Aim for **3 signed pilots**; overbook to 5 conversations. **Do not send until CI P0 (sim) is green.** Fleet Part B is optional unless the pitch includes live LAN dispatch.

---

## Reserves — remote email only (not worth the drive from Norfolk)

| # | Company | Contact | Size | Date contacted | Meeting | Outcome |
|---|---|---|---|---|---|---|
| R1 | Direct Driver Ltd (Huddersfield) | [directdriver.co.uk](https://directdriver.co.uk/) | ~10 vehicles | | | |
| R2 | Alfie Adams Transport (Bolton / Manchester) | 07941 633788 · Alfieadamstransport@gmail.com · [alfieadamstransport.co.uk](https://www.alfieadamstransport.co.uk/) | ~4 wagons | 2026-09-03 | | mailto opened earlier — optional remote only |
| R3 | Allan Greenwood Haulage (Halifax) | [allangreenwoodhaulage.co.uk](https://allangreenwoodhaulage.co.uk/) | Family + ~3 drivers | | | |
| R4 | F.C. Transport Leeds Ltd (Wakefield) | [fctransportleedsltd.co.uk](https://www.fctransportleedsltd.co.uk/) | Small mixed fleet | | | |
| R5 | Harris Haulage Ltd (Dudley / Bridgnorth) | 07733 118 973 · craigharrishaulage@outlook.com | Family mixed fleet | | | |

Other distant reserves: Froggatt’s (Chesterfield · 01246 826 771), Fosters Haulage (Bury · 07778 742089), Smalldene Midlands (Birmingham tippers).

---

## Cold email / LinkedIn / door intro (≤90 words)

> Hi [Name] — I’m building **RouteFinder**, an HGV navigation app with vehicle physics rehearsal and a **dispatch console** (Mac, iPad, or browser on your office LAN) that pushes trips to driver iPhones.  
> I’d like **10 minutes** on site: free **60-day pilot** for up to 3 phones in exchange for brutal feedback on routing edge cases (bridges, weight limits, LEZ).  
> Can I buy a coffee next week and run a live push → route → walkaround demo?

### Ready-to-send variants — Norfolk (copy after CI P0 Pass)

**N1 — J Medler (Norwich)**  
> Hi Dean / team — I’m based in Norfolk and building **RouteFinder**: HGV constraint routing + physics rehearsal + a LAN dispatch console (Mac / iPad / browser) that pushes trips to driver iPhones. Ten minutes on site: free **60-day / 3-phone** pilot for frank feedback on bridges / weight / LEZ. Coffee next week for a live push → route → walkaround demo?

**N2 — Richardson Truck Services (Bradenham)**  
> Hi — small Norfolk fleets like yours are exactly who I’m building for. **RouteFinder** does HGV routing + LAN dispatch push to iPhones (no per-seat SaaS). Free **60-day / 3-phone** pilot for honest routing feedback. Can I buy a coffee and demo push → route → walkaround next week? 07901 is on your site if a call is easier.

**N3 — Gary Chapman & Son**  
> Hi — I’m nearby and building **RouteFinder** (HGV nav + LAN dispatch, not a monthly portal). Looking for **10 minutes** on site: free **60-day pilot** (3 phones) for brutal edge-case routing feedback. Coffee + live demo next week?

**N4 — T.G. Askew (Bressingham)**  
> Hi — I’m building **RouteFinder** for independents: physics-aware HGV routing and a **LAN dispatch console** that pushes jobs to iPhones on your Wi‑Fi. Free **60-day / 3-phone** pilot for honest feedback. Ten minutes on site next week for push → route → walkaround?

**N5 — Norfolk generic door intro**  
> Hi — I’m building **RouteFinder**, HGV nav with physics rehearsal and Mac/browser LAN dispatch (no SaaS seats). Free **60-day pilot** for up to 3 phones in exchange for brutal bridge / weight / LEZ feedback. Coffee next week for a live demo?

---

## Two-minute talk track (in person)

1. **Hook (20 s):** “CoPilot-class constraint routing + physics ETA, but dispatch stays on hardware you already own — LAN Bonjour, not a monthly portal.”
2. **Demo (60 s):** Start fleet server → push trip (web or Mac) → phone toast → Find route → Rehearse → show trip brief / walkaround defect card on dispatch.
3. **Ask (20 s):** “Three phones, sixty days, one feedback form. If it wastes your time, we stop. If it helps, we talk a small desk fee after.”
4. **Close (20 s):** Leave pilot agreement; book install day; get vehicle UUID process agreed.

**Do not promise:** live telematics map, hosted web portal, CarPlay, Android Auto, full Android navigation, remote VU, or 24/7 support.

**If asked about Android:** “Pilots run on iPhone today; Android driver app for trip receive is on the roadmap; full Android navigation follows pilot feedback.”

**If asked about Windows office PCs:** “Native dispatch is Mac/iPad today; a LAN web dispatch console is available so the office can push trips from a browser.”

---

## Device / platform objections log

When a prospect objects to iPhone-only or Mac-only, log here **and** add a row in [`pilot-feedback-backlog.md`](pilot-feedback-backlog.md).

| Date | Company | Objection | Detail |
|------|---------|----------|--------|
| | | Android drivers / Windows office / other | |

---

## Bring bag

- MacBook with Xcode / RouteFinderMac + `RouteFinderFleetServer` (+ optional `web-dispatch` in Chrome)
- ORS (and optional TomTom) keys already in Settings
- 1–2 loaner iPhones **or** drivers’ personal phones (TestFlight / ad-hoc as available)
- USB-C / Lightning cable, battery pack
- Printed agreement + feedback form
- Offline demo corridor fallback if Wi‑Fi is hostile (Part C demo dispatch)

---

## After each meeting

- [ ] Log outcome in the target table
- [ ] If yes: schedule install; capture Wi‑Fi constraints and who owns the dispatch Mac / office PC
- [ ] If “need map of trucks”: note in [`pilot-feedback-backlog.md`](pilot-feedback-backlog.md) — do **not** build until two pilots demand it
- [ ] If no: ask one referral
