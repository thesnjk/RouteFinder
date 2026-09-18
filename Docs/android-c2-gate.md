# Android C2 gate — full HGV navigator

Full Android navigation (ORS routing, physics rehearsal, LEZ, voice TBT, offline graph, HOS) is a **12–18 month** greenfield Kotlin rewrite. Do **not** start C2 until this gate passes.

Last updated: 2026-09-04

---

## Status (system audit)

**LOCKED.** Zero paying pilots. Do not build Android C2, hosted multi-tenant portal, live telematics map, or production CarPlay until the decision matrix in [`pilot-feedback-backlog.md`](pilot-feedback-backlog.md) shows ≥2 renewals blocked.

Related mid-market items (also pilot-gated):

| Signal | Build only when |
|--------|-----------------|
| Android drivers block renewal | This C2 gate unlocks |
| Remote depot (no LAN) | Minimal hosted relay after VPN guide fails for ≥2 pilots |
| Trucks on a map | Periodic GPS on `FleetTripSnapshot` if ≥2 fleets demand |
| CarPlay | Paid Apple Developer team + device QA after demand |

---

## Gate criteria (all required)

| # | Criterion | How to verify |
|---|-----------|---------------|
| 1 | **≥2 paying / renewing pilots** say they cannot renew or expand because drivers are on Android | Rows in [`pilot-feedback-backlog.md`](pilot-feedback-backlog.md) + pricing log |
| 2 | **Android C1** fleet receive client works on LAN (SSE + snapshot) with those fleets | [`../android-fleet-driver/README.md`](../android-fleet-driver/README.md) |
| 3 | **Web or Mac dispatch** can push trips to mixed iOS + Android drivers | Web: [`../web-dispatch/`](../web-dispatch/) |
| 4 | Written decision: **greenfield Kotlin** vs **routing microservice** (thin Android client) | Record below |

Until then: invest in pilots, legal, web dispatch, and C1 polish only.

---

## Evidence log

| Date | Pilot | Blocks renewal? | Notes |
|------|-------|-----------------|-------|
| | | yes / no | |

**C2 unlock date:** _not yet_

**Chosen C2 approach:** greenfield Kotlin (fleet ORS proxy client) — see Implementation status below

---

## What C2 is NOT

- Android Auto (deferred until phone nav works)
- Hosted SaaS requirement
- Feature parity day-one with every iOS polish item

---

## When unlocked — first C2 milestone

1. ORS keyed routing with HGV profile on Android map (MapLibre Native) — prefer fleet ORS proxy
2. Turn-by-turn progress + metric voice
3. Accept Driver Terms + Privacy Policy in-app
4. Share vehicle UUID / fleet settings with C1

**Implementation status (2026-09-11):** C2 MVP landed in [`../android-fleet-driver/`](../android-fleet-driver/) (fleet proxy routing, MapLibre, metric TTS, SSE handoff, grade rehearsal). Device QA: [`phase6b-android-nav-verification.md`](phase6b-android-nav-verification.md). Pilot renewal gate above remains the product unlock for prioritizing further parity work.

**Chosen C2 approach:** greenfield Kotlin in-app navigator (thin client calling office fleet ORS/Pelias proxy).
