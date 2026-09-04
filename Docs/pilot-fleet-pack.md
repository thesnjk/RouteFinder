# Pilot fleet pack

Materials for a **60-day free pilot** with small UK independents (5–15 trucks). RouteFinder already ships native Mac/iPad dispatch + LAN HTTP/SSE — this pack documents what you bring to a meeting, not a new web portal.

Last updated: 2026-09-03

---

## 1. One-page pilot agreement (template)

**Parties:** RouteFinder developer (“Provider”) and ________________ (“Operator”).

**Term:** 60 days from first successful LAN demo, unless either party ends earlier on 7 days’ notice.

**What Provider supplies (at no charge):**

- RouteFinderMac dispatch console + `RouteFinderFleetServer` on Operator’s office LAN (or VPN)
- RouteFinderApp on up to **3 driver iPhones** for the pilot window
- Setup assistance for org/vehicle registration, Bonjour discovery, and one rehearsal trip
- Written feedback form (section 4)

**What Operator supplies:**

- One transport supervisor or fleet manager as primary contact
- Same Wi‑Fi/LAN for dispatch Mac and pilot phones (or agreed VPN)
- Honest feedback within 14 days of go-live and again at day 45–60
- Confirmation that drivers have accepted in-app **Driver Terms**

**Advisory-only / no SLA**

Routing, physics rehearsal, layby/HOS advisories, and turn-by-turn guidance are **advisory planning aids**. Physical road signs, bridge height/weight plates, and live traffic conditions always supersede the app. Provider gives **no warranty**, **no uptime SLA**, and **no liability** for routing errors, bridge strikes, fines, or lost time. Operator remains responsible for DVSA/Traffic Commissioner compliance.

**Data**

- Default: trip and inspection data stay on Operator’s LAN devices and local fleet store.
- Optional remote URL / TLS is Operator’s choice and Operator’s network risk.
- Provider does not sell Operator data. Provider may use **anonymised** feedback to improve the product.
- Privacy draft: [`legal/privacy-policy.md`](legal/privacy-policy.md) (solicitor review pending).

**Confidentiality**

Operator must keep confidential Provider’s non-public product demos, unpublished features, pricing discussions, source materials, and technical architecture disclosed during the pilot. Operator may not copy, photograph for publication, or disclose those materials to competitors or the press without Provider’s prior written consent, except information that is already public or that Operator must disclose by law. Provider likewise keeps Operator’s operational data and commercial details confidential. This clause survives for **three (3) years** after the pilot ends.

**Intellectual property**

All RouteFinder software, branding, and documentation remain Provider’s property. Feedback may be used by Provider in anonymised form. No licence to Provider’s source code is granted by this pilot.

**Pricing after pilot**

No obligation to buy. If Operator continues, parties may discuss a **dispatch-desk fee** (indicative: **£29–£49/mo for ≤10 trucks on LAN**) with **routing API cost included** when Provider/operator runs `RouteFinderFleetServer` with `--ors-key` (fair-use daily caps; see [`unit-economics.md`](unit-economics.md)). Owner-operator App Store pricing is deferred until after pilot feedback.

**Signatures**

| | Name | Role | Date | Signature |
|---|---|---|---|---|
| Provider | | | | |
| Operator | | | | |

---

## 2. Fleet API surface (existing — do not invent a parallel schema)

Canonical models: [`FleetModels.swift`](../RouteFinder/Sources/Contracts/Fleet/FleetModels.swift).  
Router: [`FleetRouterBuilder.swift`](../RouteFinder/Sources/FleetServerCore/FleetRouterBuilder.swift).  
Ops guide: [README — Fleet LAN server](../README.md#fleet-lan-server-multi-device-sync) and [`fleet-e2e-qa.md`](fleet-e2e-qa.md).

### Endpoints

| Method | Path | Body / notes |
|---|---|---|
| `GET` | `/health` | `FleetServerHealthResponse` `{ ok, version }` — public even when API key set |
| `GET` | `/v1/proxy/status` | `{ orsConfigured, routesToday, routeDailyCap, geocodeToday, geocodeDailyCap }` |
| `POST` | `/v1/proxy/ors/v2/directions/...` | Operator-paid ORS proxy (requires `--ors-key`) |
| `POST` | `/v1/orgs` | `{ "name": "…" }` → `FleetOrg` |
| `GET` | `/v1/orgs` | List orgs |
| `GET` | `/v1/orgs/{orgId}/vehicles` | List vehicles |
| `POST` | `/v1/vehicles` | `FleetVehicle` JSON |
| `POST` | `/v1/trips` | `FleetTrip` JSON — pushes trip and emits SSE `tripPushed` |
| `GET` | `/v1/trips/{tripId}` | Fetch trip |
| `GET` | `/v1/vehicles/{vehicleId}/active-trip` | Active trip or 204 |
| `GET` | `/v1/vehicles/{vehicleId}/events` | **SSE** — `tripPushed` + heartbeats |
| `PUT` | `/v1/trips/{tripId}/snapshot` | `FleetTripSnapshot` — physics ETA, layby, optional inspection PDF base64 |

Optional auth: `Authorization: Bearer <api-key>` when server started with `--api-key`.

Bonjour: `_routefinder-fleet._tcp`.

### Example trip push payload

```json
{
  "id": "00000000-0000-4000-8000-000000000001",
  "orgId": "00000000-0000-4000-8000-000000000010",
  "vehicleId": "00000000-0000-4000-8000-000000000020",
  "status": "dispatched",
  "stops": [
    {
      "id": "00000000-0000-4000-8000-000000000031",
      "sequence": 0,
      "label": "Felixstowe",
      "latitude": 51.95,
      "longitude": 1.35,
      "role": "origin"
    },
    {
      "id": "00000000-0000-4000-8000-000000000032",
      "sequence": 1,
      "label": "Manchester",
      "latitude": 53.48,
      "longitude": -2.24,
      "role": "destination"
    }
  ],
  "companyBreaks": [],
  "updatedAt": "2026-08-29T12:00:00Z"
}
```

Swift types for stops/roles/status: `FleetTripStop.Role`, `FleetTripStatus`. Vehicle dimensions for routing live on the **driver app** vehicle profile (Settings), not in the trip push body unless `vehicleProfile` is set on the trip.

### What is not in the API today

- Live GPS coordinate pings / continuous telematics map
- Hosted multi-tenant SaaS portal
- Public internet exposure (LAN/VPN only)

Add location snapshots only if a pilot names it as a blocker — see [`pilot-feedback-backlog.md`](pilot-feedback-backlog.md).

---

## 3. Setup checklist (condensed from Fleet Part B)

**Before the meeting**

- [ ] P0 device QA green on your own iPhone (C1–C2, C8) — [`phase20-verification.md`](phase20-verification.md)
- [ ] Mac + iPhone on same Wi‑Fi; ORS key saved if demoing live HGV route find
- [ ] Print or PDF this pack + Driver Terms (Settings → Legal)

**On site (~15 min)**

| Step | Dispatch Mac | Driver iPhone |
|---|---|---|
| 1 | `cd RouteFinder && swift run RouteFinderFleetServer --port 8080` | — |
| 2 | RouteFinderMac → Dispatch Console → org + vehicle; copy **vehicle UUID** | — |
| 3 | — | Settings → Fleet & Dispatch → Discover → Test connection |
| 4 | — | Paste vehicle UUID → Save; enable remote fleet |
| 5 | Push 2–3 stop trip | Toast via SSE within ~5 s |
| 6 | — | Accept → Find route → Rehearse Route |
| 7 | — | Share trip brief; optional walkaround with a defect |
| 8 | Confirm snapshot / inspection card on console | — |

Full steps and troubleshooting: [`fleet-e2e-qa.md`](fleet-e2e-qa.md) Part B.

**Single-device fallback:** Settings → Fleet → Accept demo dispatch (no LAN).

---

## 4. Feedback form

Operator: ________________  Date: ________  Vehicles on pilot: ____

| # | Topic | What happened? | Severity (1–5) | Willing to retest? |
|---|---|---|---|---|
| F1 | Bridge height / low structure near-miss | | | |
| F2 | Weight / axle / temporary restriction | | | |
| F3 | LEZ / CAZ surprise | | | |
| F4 | Layby / Break Now quality | | | |
| F5 | Dispatch push reliability (SSE/toast) | | | |
| F6 | Walkaround → dispatch inspection | | | |
| F7 | Physics ETA trust vs driver gut | | | |
| F8 | Setup friction (Bonjour, keys, UUID) | | | |
| F9 | Need live truck on dispatch map? | Y/N — why: | | |
| F10 | Would pay after 60 days? | Amount / model: | | |

Free-text (attach screenshots / plate / approx location):

_________________________________________________________________

Triage outcomes into [`pilot-feedback-backlog.md`](pilot-feedback-backlog.md).

---

## Related

- Pitch / outreach script: [`pilot-outreach.md`](pilot-outreach.md)
- Pricing context: [`competitor-pricing-2026.md`](competitor-pricing-2026.md)
- Personas: [`buyer-personas-uk-hgv.md`](buyer-personas-uk-hgv.md)
