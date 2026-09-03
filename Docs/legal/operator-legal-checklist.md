# Operator legal checklist (Track A)

Do these yourself. The agent drafts docs; a solicitor reviews them. **Do not skip solicitor review before App Store or paid pilots.**

Last updated: 2026-09-03

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

Ask them to review:

- [`privacy-policy.md`](privacy-policy.md)
- [`terms-of-service.md`](terms-of-service.md)
- In-app Driver Terms (`ProductOnboardingSheet`)
- [`../pilot-fleet-pack.md`](../pilot-fleet-pack.md) pilot agreement + confidentiality
- Planned Android + web expansion (LAN only vs hosted)

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

Confirm you trade as a **Ltd** (or form one via [Companies House](https://www.gov.uk/limited-company-formation/register-your-company)). Put the Ltd name on LICENSE, Privacy Policy, ToS, and pilot agreements.

| Entity name | Companies House number | Confirmed |
|-------------|------------------------|-----------|
| | | |

---

## 4. Domains and handles

Register early (name may be crowded):

| Asset | Status |
|-------|--------|
| Primary domain | |
| GitHub org | |
| LinkedIn / X | |

---

## 5. After solicitor signs off

Tell the agent to wire Privacy Policy + ToS into App Store Connect and Settings URLs (hosted HTML or GitHub Pages). Until then, drafts live under `Docs/legal/`.
