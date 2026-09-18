# App Store Connect metadata (draft)

**Status:** Operator paste-ready draft — not submitted. Align URLs with [`legal/site/README.md`](legal/site/README.md) after you host HTML.  
**Last updated:** 2026-09-17

---

## 1. Privacy Policy and licence URLs

| Field | Value (placeholder until hosted) |
|-------|----------------------------------|
| **Privacy Policy URL** | `https://routefinder.app/legal/privacy` |
| **License Agreement** | Choose **Custom** and set EULA / Terms URL to `https://routefinder.app/legal/terms` **or** use Apple’s Standard EULA and keep Terms linked in-app only |

Must match `ProductLegalDocuments.legalURLBase` and Android `LEGAL_*_URL` constants.

---

## 2. Listing copy (GB English)

**Name:** RouteFinder

**Subtitle (≤30 characters):** `HGV nav + fleet dispatch`

**Promotional text (optional, editable anytime):**  
UK HGV routing with physics rehearsal and a LAN dispatch desk that pushes trips to driver phones — no per-seat portal tax.

**Description:**

```
RouteFinder is professional HGV navigation and small-fleet dispatch for UK independents.

• Constraint-aware truck routing and physics route rehearsal
• Turn-by-turn guidance with lane hints from OpenStreetMap where available
• Named UK toll advisories along your route (hints only — not live tariffs)
• Walkaround inspections and shareable trip briefs
• Mac / iPad / browser dispatch on your office Wi‑Fi: push trips to drivers over LAN
• Optional remote depot via your own hosted gateway (Operator-run VPS)

Routing and advisories are planning aids. Road signs, bridge plates, and the digital tachograph always win.

Fleet pilots: up to 3 phones for 60 days under a signed pilot agreement. Post-pilot desk subscription includes fair-use routing API via your fleet server — see the pilot pack.
```

**Keywords (comma-separated, ≤100 characters):**  
`HGV,truck,navigation,fleet,dispatch,UK,lorry,routing,haulage`

**Support URL:** your support / contact page (or GitHub Issues / email landing).  
**Marketing URL (optional):** product landing page when ready.

**What’s New (1.0):**  
Initial release: HGV routing, physics rehearsal, LAN fleet dispatch, advisory Driver Terms.

---

## 3. App Privacy questionnaire mapping

Map App Store Connect **App Privacy** answers to [`legal/privacy-policy.md`](legal/privacy-policy.md) §2. Suggested starting point (confirm with solicitor):

| Data type | Collect? | Linked to identity? | Used for tracking? | Purpose notes |
|-----------|----------|---------------------|--------------------|---------------|
| **Precise Location** | Yes (when navigating / follow mode) | No (stays on device / Operator fleet store) | No | App functionality — navigation, optional trip snapshot pin |
| **Coarse Location** | Optional / if OS provides | No | No | Same as above if declared separately |
| **Product Interaction** | No (unless you add analytics later) | — | — | Do not claim analytics until implemented |
| **Crash Data** | Only if you enable a crash reporter later | — | — | Default: none beyond Apple’s optional diagnostics |
| **Identifiers** | Device / vendor IDs only as needed by OS | No | No | Not sold; not used for third-party ads |
| **User Content** (trip stops, inspections, vehicle profile) | Yes | May be Operator-linked on LAN | No | App functionality — fleet ops on Operator store |
| **Other User Content** (telematics CSV / ingest) | Yes if Operator imports | Operator-controlled | No | Display only — not legal VU |
| **Payment Info** | No in-app purchase yet | — | — | Desk fees are offline / invoice |

**Data Not Collected** for advertising / third-party advertising / tracking — RouteFinder does not run ad SDKs in this draft.

---

## 4. Review notes (App Review)

Suggested notes for reviewers:

```
RouteFinder is an HGV navigation and small-fleet dispatch tool.

Demo path without LAN fleet:
1. Accept Driver Terms on first launch.
2. Enter origin/destination (or use map) → Find route → Rehearse / Play.
3. Settings → Legal shows Privacy Policy and Terms links.

Optional fleet demo (if reviewer has second device on same network):
- Run RouteFinderFleetServer; pair via Settings → Fleet.
- Otherwise fleet features are optional and not required to review core navigation.

Routing outputs are advisory only. We do not claim certified LEZ, tachograph, or toll billing compliance.
```

**Demo account:** not required for single-device navigation. For fleet, provide a TestFlight build + short LAN setup only if Review requests it.

**TestFlight vs production:** use TestFlight for pilot phones; production App Store build after solicitor sign-off and hosted legal URLs are live.

---

## 5. Export compliance / encryption

RouteFinder uses **standard HTTPS** (TLS) for optional API calls and fleet HTTP. No proprietary encryption algorithms beyond OS networking.

**Suggested App Store answer:** App uses encryption solely for standard encryption within HTTPS — typically **exempt** from export documentation (`ITSAppUsesNonExemptEncryption` = **NO** when only exempt encryption is used).

Confirm with Apple’s current questionnaire wording at submit time. Add to `Info.plist` only if your Xcode / ASC flow requires the key:

```xml
<key>ITSAppUsesNonExemptEncryption</key>
<false/>
```

Not added automatically in Phase 9 — set when you create the App Store archive.

---

## 6. Categories and age

- **Primary category:** Navigation  
- **Secondary (optional):** Business  
- **Age rating:** 4+ (no unrestricted web, no gambling, professional tool) — complete Apple’s age rating questionnaire honestly (location features do not raise the rating by themselves).

---

## 7. CarPlay / entitlements

Only claim CarPlay in screenshots/copy if the **paid Apple Developer** build includes CarPlay entitlements (see [`carplay-weatherkit-restore.md`](carplay-weatherkit-restore.md)). Personal-team builds strip CarPlay — do not advertise CarPlay on those binaries.

---

## Related

- Hosted HTML: [`legal/site/`](legal/site/)
- Operator checklist: [`legal/operator-legal-checklist.md`](legal/operator-legal-checklist.md)
- Verification: [`phase9-legal-gtm-verification.md`](phase9-legal-gtm-verification.md)
