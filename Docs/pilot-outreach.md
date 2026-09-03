# Pilot outreach — local fleet managers

Operator-run playbook for booking **3–5** small independent haulage/courier meetings (5–15 trucks), within driving distance for LAN demos.

Last updated: 2026-09-03

---

## Prerequisites (do not pitch until done)

1. **CI green on `main`** (simulator P0) — [`phase20-verification.md`](phase20-verification.md) P49b-P0 / P57-7 **Pass (CI sim)**, or [`operator-next-steps.md`](operator-next-steps.md) Block 1
2. Optional: Block 1b phone smoke (voice, Device Hub resize, real Keychain) before first meeting
3. Print [`pilot-fleet-pack.md`](pilot-fleet-pack.md) (agreement + feedback form)
4. Fleet Part B LAN dry-run only if pitching dispatch console on site

---

## Target list (draft — northern England / Midlands; swap for nearer firms if needed)

| # | Company | Contact | Size | Date contacted | Meeting | Outcome |
|---|---|---|---|---|---|---|
| 1 | Direct Driver Ltd (Huddersfield) | [directdriver.co.uk](https://directdriver.co.uk/) · door / site | ~10 vehicles | | | |
| 2 | Alfie Adams Transport (Bolton / Manchester) | 07941 633788 · Alfieadamstransport@gmail.com · [alfieadamstransport.co.uk](https://www.alfieadamstransport.co.uk/) | ~4 wagons | 2026-09-03 | | mailto open — **hit Send** or call 07941 633788; then set Outcome to email sent / voicemail / spoke |
| 3 | Allan Greenwood Haulage (Halifax) | [allangreenwoodhaulage.co.uk](https://allangreenwoodhaulage.co.uk/) · door / site | Family + ~3 drivers | | | |
| 4 | F.C. Transport Leeds Ltd (Wakefield) | [fctransportleedsltd.co.uk](https://www.fctransportleedsltd.co.uk/) · door / site | Small mixed fleet | | | |
| 5 | Harris Haulage Ltd (Dudley / Bridgnorth) | 07733 118 973 · craigharrishaulage@outlook.com | Family mixed fleet | | | |

**Reserves:** Froggatt’s (Chesterfield · 01246 826 771), Fosters Haulage (Bury · 07778 742089), Smalldene Midlands (Birmingham tippers).

Aim for **3 signed pilots**; overbook to 5 conversations. **Do not send until CI P0 (sim) is green.** Fleet Part B is optional unless the pitch includes live LAN dispatch.

---

## Cold email / LinkedIn / door intro (≤90 words)

> Hi [Name] — I’m building **RouteFinder**, an HGV navigation app with vehicle physics rehearsal and a **Mac dispatch console** that pushes trips to driver iPhones on your office Wi‑Fi (no per-seat SaaS).  
> I’d like **10 minutes** on site: free **60-day pilot** for up to 3 phones in exchange for brutal feedback on routing edge cases (bridges, weight limits, LEZ).  
> Can I buy a coffee next week and run a live push → route → walkaround demo?

### Ready-to-send variants (copy after CI P0 Pass)

**1 — Direct Driver (Huddersfield)**  
> Hi Kurtis / team — I’m building **RouteFinder**, HGV nav with physics rehearsal and a **Mac dispatch console** on your office Wi‑Fi (no per-seat SaaS). Ten minutes on site: free **60-day pilot** for up to 3 phones for brutal feedback on bridges / weight / LEZ. Coffee next week for a live push → route → walkaround demo?

**2 — Alfie Adams (Bolton)**  
> Hi — small family fleets like yours are exactly who I’m building for. **RouteFinder** does HGV constraint routing + a Mac dispatch push to driver iPhones on LAN. Free **60-day / 3-phone** pilot for frank routing feedback. Can I buy a coffee and demo push → route → walkaround next week? 07941 is on your site if a call is easier.

**3 — Allan Greenwood (Halifax)**  
> Hi Sheridan / Pete / Gavin — I’m nearby and building **RouteFinder** (HGV nav + Mac LAN dispatch, not a monthly portal). Looking for **10 minutes** on site: free **60-day pilot** (3 phones) for brutal feedback on edge-case routing. Coffee + live demo next week?

**4 — F.C. Transport (Wakefield)**  
> Hi — I’m building **RouteFinder** for independents: physics-aware HGV routing and a **Mac dispatch console** that pushes jobs to iPhones on your Wi‑Fi. Free **60-day / 3-phone** pilot for honest feedback. Ten minutes on site next week for push → route → walkaround?

**5 — Harris Haulage (Dudley / Bridgnorth)**  
> Hi Craig — I’m building **RouteFinder**, HGV nav with physics rehearsal and Mac LAN dispatch (no SaaS seats). Free **60-day pilot** for up to 3 phones in exchange for brutal bridge / weight / LEZ feedback. Coffee next week for a live demo?

---

## Two-minute talk track (in person)

1. **Hook (20 s):** “CoPilot-class constraint routing + physics ETA, but dispatch stays on hardware you already own — LAN Bonjour, not a monthly portal.”
2. **Demo (60 s):** Start fleet server → push trip → phone toast → Find route → Rehearse → show trip brief / walkaround defect card on dispatch.
3. **Ask (20 s):** “Three phones, sixty days, one feedback form. If it wastes your time, we stop. If it helps, we talk a small desk fee after.”
4. **Close (20 s):** Leave pilot agreement; book install day; get vehicle UUID process agreed.

**Do not promise:** live telematics map, hosted web portal, CarPlay, Android Auto, full Android navigation, remote VU, or 24/7 support.

**If asked about Android:** “Pilots run on iPhone today; Android driver app for trip receive is on the roadmap; full Android navigation follows pilot feedback.”

**If asked about Windows office PCs:** “Native dispatch is Mac/iPad today; a LAN web dispatch console is in progress so the office can push trips from a browser.”

---

## Device / platform objections log

When a prospect objects to iPhone-only or Mac-only, log here **and** add a row in [`pilot-feedback-backlog.md`](pilot-feedback-backlog.md).

| Date | Company | Objection | Detail |
|------|---------|----------|--------|
| | | Android drivers / Windows office / other | |

---

## Bring bag

- MacBook with Xcode / RouteFinderMac + `RouteFinderFleetServer`
- ORS (and optional TomTom) keys already in Settings
- 1–2 loaner iPhones **or** drivers’ personal phones (TestFlight / ad-hoc as available)
- USB-C / Lightning cable, battery pack
- Printed agreement + feedback form
- Offline demo corridor fallback if Wi‑Fi is hostile (Part C demo dispatch)

---

## After each meeting

- [ ] Log outcome in the target table
- [ ] If yes: schedule install; capture Wi‑Fi constraints and who owns the dispatch Mac
- [ ] If “need map of trucks”: note in [`pilot-feedback-backlog.md`](pilot-feedback-backlog.md) — do **not** build until two pilots demand it
- [ ] If no: ask one referral
