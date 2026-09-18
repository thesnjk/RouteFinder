# Phase 9 — Legal and GTM verification

Manual QA after Phase 9 drafts. Solicitor / trademark / App Store submit remain **operator** actions.

Last updated: 2026-09-17

---

## In-repo drafts

- [ ] [`legal/privacy-policy.md`](legal/privacy-policy.md) mentions web-dispatch, Android, hosted gateway, snapshots, telematics stub, toll hints
- [ ] [`legal/terms-of-service.md`](legal/terms-of-service.md) includes API-included fees + fair-use
- [ ] [`legal/driver-terms.md`](legal/driver-terms.md) matches in-app Driver Terms body
- [ ] [`legal/site/privacy.html`](legal/site/privacy.html) and [`terms.html`](legal/site/terms.html) open locally in a browser
- [ ] [`legal/site/README.md`](legal/site/README.md) publish steps readable
- [ ] [`app-store-connect-metadata.md`](app-store-connect-metadata.md) has URLs, description, privacy mapping, review notes
- [ ] [`pilot-fleet-pack.md`](pilot-fleet-pack.md) pricing table anchors **£39/mo** Desk LAN; API section lists snapshot GPS + telematics ingest
- [ ] [`unit-economics.md`](unit-economics.md) pricing table matches pilot pack
- [ ] [`legal/operator-legal-checklist.md`](legal/operator-legal-checklist.md) §6 agent deliverables checked; §7 left for you
- [ ] [`pilot-outreach.md`](pilot-outreach.md) Norfolk N1–N5 + subject lines + voicemail; send log present

---

## In-app (iOS / macOS)

- [ ] Settings → Legal → Driver Terms disclosure shows body
- [ ] Privacy Policy summary readable offline
- [ ] **Open full Privacy Policy** link present (`legalPrivacyPolicyLink`) → opens `https://routefinder.app/legal/privacy` (or your replaced domain)
- [ ] **Open full Terms of Service** link present (`legalTermsOfServiceLink`) → opens terms URL
- [ ] After you host HTML: links show live pages (no 404); App Store Connect Privacy URL matches

UITest (optional local): `testSettingsAPIUsageAndLegalDriverTerms` in `RouteFinderAppUITests`.

---

## Android

- [ ] Driver Terms screen shows privacy/terms placeholder URLs (`LEGAL_PRIVACY_URL` / `LEGAL_TERMS_URL`)

---

## Pricing consistency

| Source | Desk LAN anchor |
|--------|-----------------|
| pilot-fleet-pack | £39/mo ≤10 trucks |
| unit-economics | £39/mo ≤10 trucks |
| terms-of-service §6 | £39/mo indicative |
| outreach talk track | ~£39/mo |

- [ ] All four agree

---

## Operator-only (not agent)

- [ ] Solicitor review booked / completed
- [ ] Ltd placeholders replaced
- [ ] HTML hosted on HTTPS
- [ ] Trademark decision logged
- [ ] Norfolk N1–N5 actually sent / visited
- [ ] App Store Connect listing pasted from metadata doc

---

## Automated smoke

```bash
# From RouteFinder package (optional)
cd RouteFinder && swift build --target UI

# Hosted gateway / web not required for Phase 9
```
