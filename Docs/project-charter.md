# RouteFinder — project charter

**Source of truth for current direction.** Operating rules live in the local agent master prompt (`Docs/agent-master-prompt.md`, never committed). Last updated: 2026-11-17.

Evidence labels used below: **Verified fact** · **Reasoned inference** · **Working assumption** · **Proposed experiment** · **Unresolved question**.

---

## Identity

| Field | Value |
|-------|--------|
| **Project name** | RouteFinder |
| **One-line description** | UK HGV constraint-aware navigator + lightweight fleet desk (cab phone + Mac/web dispatch over LAN or hosted HTTPS) |
| **Owner** | Jacob Hackett |
| **Repository** | Proprietary — see root `LICENSE` |

---

## Current strategic posture

| Field | Value |
|-------|--------|
| **Posture** | **NARROW** |
| **Meaning** | Engineering MVP is largely shipped; focus is Norfolk/East Anglia paid-pilot validation for the existing ICP—not new surfaces, not broad pivots, not densify grind |
| **Next decision gate** | After ≥3 discovery conversations with workflow evidence **and** ≥1 signed/started free pilot **or** clear refusal pattern → refresh [`research/validation-scorecard.md`](research/validation-scorecard.md) and choose GO / NARROW / PIVOT / STOP explicitly |

**Verified fact:** Competitive scorecard / sweep mark ungated cab/desk product residuals exhausted; remaining product epics need paid secrets/entitlements (CarPlay, Android Auto, VU partner, live toll £, HD lanes, Stripe, Android offline packs, further country PBF).  
**Verified fact:** Senior technical monograph (`project-writeup.md`) is complete (living Doc).  
**Working assumption:** Free 60-day / ≤3-phone pilot → API-included desk subscription is the near-term commercial path ([`pilot-fleet-pack.md`](pilot-fleet-pack.md)).

---

## Customer, problem, workflow, outcome

| Field | Value | Label |
|-------|--------|--------|
| **Primary customer** | Small-fleet transport manager / owner (“Sarah”) — ≈2–20 trucks; ICP wedge **5–15 trucks** | Working assumption (personas Doc) |
| **Secondary customer** | UK owner-operator (“Dave”) — App Store SKU **deferred** post-pilot | Working assumption |
| **Primary problem** | Consumer maps ignore HGV constraints; truck-nav peers lack physics rehearsal + lightweight desk coupling; telematics is heavy SaaS | Reasoned inference from competitive Docs |
| **Primary workflow** | Office creates/pushes constrained trip → cab receives / routes / rehearses → advisory HOS + UK living-layer advisories → desk sees roster/snapshots | Verified fact (shipped product) |
| **Promised outcome** | Fewer unsuitable roads / surprise LEZ exposure; shareable trip risk brief; office–cab sync without per-seat CoPilot tax | Working assumption (pilot value hypothesis) |

---

## Revenue model

| Stage | Model | Indicative | Label |
|-------|--------|------------|--------|
| Pilot | Free setup + feedback | **£0** / ≤3 phones / 60 days | Verified fact (pilot pack template) |
| Paid desk (LAN) | API-included desk subscription | **£39/mo** band £29–£49 / ≤10 trucks | Working assumption (indicative; VAT treatment **unresolved** until invoice design) |
| Desk + remote | Hosted gateway | **£49–£79/mo** + VPS pass-through | Working assumption |
| Extra trucks | Add-on | **£3–£5/truck/mo** | Working assumption |
| Owner-operator App Store | Deferred | — | Explicit exclusion until post-pilot |

Prices are **indicative**, dated via pilot pack (2026-09). Not verified willingness-to-pay. GBP. Do not invent conversion or retention rates.

**VAT / invoice treatment:** **Unresolved** until invoice design — do not invent ex-VAT vs inc-VAT or a VAT scheme here. Same note on the pricing table in [`pilot-fleet-pack.md`](pilot-fleet-pack.md); competitor retail VAT context in [`competitor-pricing-2026.md`](competitor-pricing-2026.md) (VAT footnote).

---

## Geography and opportunities

| Field | Value |
|-------|--------|
| **Initial geography** | UK; outreach primary = **Norfolk / East Anglia** (~45 min drive demos) |
| **Active (primary) opportunity** | Small-fleet desk+cab pilot → paid API-included LAN/hosted desk |
| **Backup opportunity** | Owner-operator App Store SKU after paying-fleet signals |
| **Portfolio snapshot** | [`research/opportunity-portfolio.md`](research/opportunity-portfolio.md) |

---

## Explicit exclusions (do not build as primary track)

- Displace Samsara/Geotab as full telematics / legal VU download platform
- Unbounded London-wide ULEZ avoid (ORS area-cap blocked)
- Stripe self-serve multi-tenant SaaS billing before paid-pilot evidence
- Speculative densify / mid-corridor / toll-£ clones without scorecard hole (Anti-grind)
- Mass ads before message/offer validation
- Inventing CarPlay / Android Auto / HD / live £ / further PBF without unlock

Verdict detail / qualitative scores for these tracks: **Exclude** rows in [`research/opportunity-portfolio.md`](research/opportunity-portfolio.md) — keep that snapshot aligned with this list (no silent multi-track builds).

---

## Founder constraints

- Solo founder; agent executes engineering/Docs; founder owns outreach, solicitor, paid entitlements, secrets
- Local-only agent master prompt — never commit
- No fabricated interviews, pilots, prices, or partnerships
- Legal drafts exist; solicitor review required before paid / App Store ([`legal/operator-legal-checklist.md`](legal/operator-legal-checklist.md))

---

## As-built stack (engineering validated — not a greenfield “avoid mobile” rule)

**Verified fact:** Multi-surface system already ships — Swift 6 iOS/Mac package, Android C2 fleet driver, `web-dispatch`, LAN fleet server, optional `hosted-gateway`. New surfaces or major architecture still require commercial evidence (WTP / pilot blockers), not boredom with the current stack.

---

## Related OS Docs

| Doc | Role |
|-----|------|
| [`product-backlog.md`](product-backlog.md) | Ordered self-service next actions |
| [`research/validation-scorecard.md`](research/validation-scorecard.md) | GO / NARROW / PIVOT / STOP |
| [`developer-map.md`](developer-map.md) | Layout / tests / pointers |
| [`pilot-outreach.md`](pilot-outreach.md) | Named-account outreach tracker |
| [`pilot-fleet-pack.md`](pilot-fleet-pack.md) | Pilot agreement + pricing template |
| `agent-master-prompt.md` | Agent operating rules — **local-only; never commit** |
