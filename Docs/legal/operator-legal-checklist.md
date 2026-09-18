# Operator legal checklist (Track A)

Do these yourself. The agent drafts docs; a solicitor reviews them. **Do not skip solicitor review before App Store or paid pilots.**

Last updated: 2026-09-17

---

## 1. UK IPO trademark search (5 minutes)

Browser should already be open at [Search for a trade mark](https://www.gov.uk/search-for-trademark). If not:

```bash
open "https://www.gov.uk/search-for-trademark"
```

1. Search **RouteFinder** (and close variants: Route Finder, RouteFinder HGV).
2. Note Classes **9** (software) and **42** (SaaS / software services).
3. If clear enough to file: [Apply to register a trade mark](https://www.gov.uk/how-to-register-a-trade-mark) (~£170–£200 for one class; add Class 42).
4. Log result below.

| Date | Search term | Conflicts found? | Action |
|------|-------------|------------------|--------|
| 2026-09-03 | RouteFinder (Classes 9 / 42) | No | Clear to file — consider UK IPO application Classes 9 + 42 |

---

## 2. Book UK software / IP solicitor (~£200–£400, 1 hour)

Ask them to review this packet:

- [`privacy-policy.md`](privacy-policy.md)
- [`terms-of-service.md`](terms-of-service.md)
- [`driver-terms.md`](driver-terms.md) (in-app Driver Terms)
- [`../app-store-connect-metadata.md`](../app-store-connect-metadata.md) (Privacy questionnaire mapping)
- [`../pilot-fleet-pack.md`](../pilot-fleet-pack.md) pilot agreement + confidentiality + **API-included pricing**
- Hosted gateway privacy note: [`../hosted-gateway-deployment.md`](../hosted-gateway-deployment.md) (Operator-run VPS; per-org tokens)
- Planned surfaces already shipped: Android driver, web-dispatch, LAN + optional hosted gateway

Find a solicitor:

```bash
open "https://solicitors.lawsociety.org.uk/"
```

Filter: **Intellectual property** / **Commercial** / **Technology**, England & Wales.

| Date booked | Firm | Review due | Notes |
|-------------|------|------------|-------|
| | | | |

---

## 3. Company entity

```bash
open "https://www.gov.uk/get-information-about-a-company"
```

Confirm you trade as a **Ltd** (or form one via [Companies House](https://www.gov.uk/limited-company-formation/register-your-company)). Put the Ltd name on LICENSE, Privacy Policy, ToS, pilot agreements, and HTML under [`site/`](site/).

| Entity name | Companies House number | Confirmed |
|-------------|------------------------|-----------|
| | | |

---

## 4. Domains and handles

Register early (name may be crowded):

| Asset | Status |
|-------|--------|
| Primary domain | |
| Legal paths `/legal/privacy` + `/legal/terms` | |
| GitHub org | |
| LinkedIn / X | |

---

## 5. After solicitor signs off

1. Replace Ltd / address / `privacy@` placeholders in markdown + [`site/*.html`](site/).
2. Host HTML per [`site/README.md`](site/README.md).
3. Update `ProductLegalDocuments.legalURLBase` (and Android `LEGAL_*_URL`) if the domain is not `routefinder.app`.
4. Paste Privacy Policy URL into App Store Connect (see [`../app-store-connect-metadata.md`](../app-store-connect-metadata.md)).
5. Verify Settings → Legal links open the live pages.

Until hosted, drafts live under `Docs/legal/` and placeholder URLs point at `https://routefinder.app/legal/…`.

---

## 6. Phase 9 agent deliverables (done in-repo)

- [x] Privacy / ToS / Driver Terms markdown refreshed (Phases 4–8 product surface)
- [x] Static HTML under [`site/`](site/) + hosting README
- [x] Placeholder in-app / Android legal URLs wired
- [x] [`../app-store-connect-metadata.md`](../app-store-connect-metadata.md)
- [x] Pilot pack + unit-economics **API-included** pricing table
- [x] [`../phase9-legal-gtm-verification.md`](../phase9-legal-gtm-verification.md)

---

## 7. Pre–App Store (you)

- [ ] Solicitor written sign-off on Privacy, ToS, Driver Terms, pilot agreement
- [ ] Ltd name on all public legal docs + HTML
- [ ] Host `site/privacy.html` + `terms.html` on HTTPS
- [ ] App Store Connect Privacy Policy URL matches in-app Links
- [ ] In-app Settings → Legal opens live pages on device
- [ ] ICO registration considered if you are a controller processing personal data
- [ ] Trademark search logged; filing decision made (optional before pilots, recommended before marketing spend)
- [ ] Export compliance / encryption answer confirmed ([`../app-store-connect-metadata.md`](../app-store-connect-metadata.md) §5)
- [ ] CarPlay not claimed in listing unless paid-team entitled build
