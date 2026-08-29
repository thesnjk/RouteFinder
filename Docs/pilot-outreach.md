# Pilot outreach — local fleet managers

Operator-run playbook for booking **3–5** small independent haulage/courier meetings (5–15 trucks), within driving distance for LAN demos.

Last updated: 2026-08-29

---

## Prerequisites (do not pitch until done)

1. Physical iPhone **P0** rows C1–C2 + C8 Pass — [`phase20-verification.md`](phase20-verification.md)
2. At least one dry-run of [`fleet-e2e-qa.md`](fleet-e2e-qa.md) Part B on your own Mac + phone
3. Print [`pilot-fleet-pack.md`](pilot-fleet-pack.md) (agreement + feedback form)

---

## Target list (fill in)

| # | Company | Contact | Size | Date contacted | Meeting | Outcome |
|---|---|---|---|---|---|---|
| 1 | | | | | | |
| 2 | | | | | | |
| 3 | | | | | | |
| 4 | | | | | | |
| 5 | | | | | | |

Aim for **3 signed pilots**; overbook to 5 conversations.

---

## Cold email / LinkedIn / door intro (≤90 words)

> Hi [Name] — I’m building **RouteFinder**, an HGV navigation app with vehicle physics rehearsal and a **Mac dispatch console** that pushes trips to driver iPhones on your office Wi‑Fi (no per-seat SaaS).  
> I’d like **10 minutes** on site: free **60-day pilot** for up to 3 phones in exchange for brutal feedback on routing edge cases (bridges, weight limits, LEZ).  
> Can I buy a coffee next week and run a live push → route → walkaround demo?

---

## Two-minute talk track (in person)

1. **Hook (20 s):** “CoPilot-class constraint routing + physics ETA, but dispatch stays on hardware you already own — LAN Bonjour, not a monthly portal.”
2. **Demo (60 s):** Start fleet server → push trip → phone toast → Find route → Rehearse → show trip brief / walkaround defect card on dispatch.
3. **Ask (20 s):** “Three phones, sixty days, one feedback form. If it wastes your time, we stop. If it helps, we talk a small desk fee after.”
4. **Close (20 s):** Leave pilot agreement; book install day; get vehicle UUID process agreed.

**Do not promise:** live telematics map, hosted web portal, CarPlay, Android Auto, remote VU, or 24/7 support.

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
