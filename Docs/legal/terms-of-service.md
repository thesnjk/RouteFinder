# RouteFinder Terms of Service

**Status:** Draft for solicitor review — not legal advice.  
**Last updated:** 2026-09-17  
**Provider:** *[Ltd company name]* (replace after incorporation).

These Terms govern use of RouteFinder software, the fleet LAN server, **web dispatch** console, **Android** fleet driver app, optional **hosted gateway**, and related pilot services. Separate **Driver Terms** in the app ([`driver-terms.md`](driver-terms.md)) govern advisory routing liability. A signed **pilot agreement** may add or modify terms for a specific Operator.

Hosted copy (after you publish): `https://routefinder.app/legal/terms` — replace domain to match [`site/README.md`](site/README.md).

---

## 1. Licence

Subject to these Terms and any written agreement, Provider grants Operator a limited, non-exclusive, non-transferable licence to use RouteFinder for internal fleet / owner-operator operations. Source code remains proprietary (see repository `LICENSE`). No licence is granted to reverse engineer except where mandatory law allows.

---

## 2. Accounts and security

Operator is responsible for credentials, fleet vehicle UUIDs, org bearer tokens, and who can access the dispatch Mac / web console / LAN server / hosted gateway. Where Provider or Operator supplies operator-paid routing via the fleet ORS proxy, API keys must not be extracted or redistributed. Operator must not share production API keys or gateway tokens publicly.

---

## 3. Acceptable use

Operator must not:

- Use RouteFinder to violate road traffic, DVSA, or Traffic Commissioner rules
- Attempt unauthorised access to other Operators’ fleets or servers
- Redistribute the Software except as allowed in writing
- Misrepresent Provider’s advisory outputs as certified legal compliance (including LEZ envelopes, UK toll hints, HOS/layby advice, or telematics stubs)
- Circumvent fleet ORS / Pelias proxy fair-use caps or scrape Provider-held third-party API keys
- Treat telematics CSV / ingest as a legal Vehicle Unit or tachograph record

---

## 4. Advisory services — no warranty

Routing, physics rehearsal, LEZ awareness, **UK toll advisories** (named hints only — not tariffs), HOS/layby advice, parking partner deep links, and turn-by-turn guidance are **advisory planning aids**. Physical road signs, bridge plates, tachograph rules, and live conditions always supersede the app. Provider gives **no warranty**, **no uptime SLA**, and **no liability** for routing errors, bridge strikes, fines, lost time, or regulatory action. Operator remains responsible for compliance.

---

## 5. Fleet LAN, snapshots, and optional remote access

Default architecture is Operator LAN (`RouteFinderFleetServer` + Bonjour). Driver apps may publish **periodic GPS fields** on trip snapshots for a dispatch map pin — this is **not** continuous live telematics.

Optional remote URL / TLS or a **hosted gateway** VPS is Operator’s choice and Operator’s network and hosting risk. Hosted multi-tenant SaaS with billing UI is not included unless separately agreed.

---

## 6. Fees and included APIs

Pilot programmes may be free under a signed pilot agreement. Ongoing fees follow the **API-included desk subscription** model in [`../pilot-fleet-pack.md`](../pilot-fleet-pack.md) and [`../unit-economics.md`](../unit-economics.md) (indicative: **£39/mo** for ≤10 trucks on LAN with ORS/Pelias fair-use caps).

Where the subscription includes **operator-paid routing**, Provider or Operator covers HeiGIT ORS (and agreed optional providers) subject to published **fair-use daily caps** on the fleet proxy or hosted gateway (default 2,000 routes / 2,000 geocodes per day). Excess usage may be throttled (HTTP 429) or billed under a written addendum. Owner-operator App Store pricing, if offered, is shown at purchase time and is **deferred** until after pilot feedback.

---

## 7. Confidentiality

Each party must keep the other’s non-public technical and commercial information confidential and use it only for the permitted purpose, except information that is public, independently developed, or required by law to disclose.

---

## 8. Intellectual property

RouteFinder name, software, documentation, and trade secrets remain Provider’s property. Feedback may be used by Provider in anonymised form to improve the product. Operator retains ownership of Operator trip/inspection content.

---

## 9. Limitation of liability

To the maximum extent permitted by law, Provider’s total liability arising from these Terms is limited to the fees paid by Operator to Provider in the three months before the claim (or £100 if no fees were paid). Provider is not liable for indirect, consequential, or lost-profit damages. Nothing excludes liability that cannot be excluded by law (including death or personal injury caused by negligence, or fraud).

---

## 10. Term and termination

These Terms continue while Operator uses the Software. Either party may terminate a pilot per the pilot agreement. On termination, Operator must stop using Provider-supplied pilot builds if requested, except as law requires retention of records.

---

## 11. Governing law

England and Wales law. Courts of England and Wales have exclusive jurisdiction, subject to mandatory consumer protections if applicable.

---

## 12. Changes

Material changes will be notified in-app, by email to Operator contacts, or by updating this document’s date. Continued use after notice constitutes acceptance where permitted by law.
