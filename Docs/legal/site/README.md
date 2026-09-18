# Hosting RouteFinder legal pages

Static HTML drafts for App Store / in-app Privacy Policy and Terms of Service links.

| File | Suggested public path |
|------|------------------------|
| [`privacy.html`](privacy.html) | `https://YOUR_DOMAIN/legal/privacy` (or `/legal/privacy.html`) |
| [`terms.html`](terms.html) | `https://YOUR_DOMAIN/legal/terms` |

Markdown sources of truth (keep HTML in sync after solicitor edits):

- [`../privacy-policy.md`](../privacy-policy.md)
- [`../terms-of-service.md`](../terms-of-service.md)
- [`../driver-terms.md`](../driver-terms.md) (in-app only; optional to host)

## Placeholder used in the apps today

Until you publish and replace the domain:

| Document | Placeholder URL |
|----------|-----------------|
| Privacy | `https://routefinder.app/legal/privacy` |
| Terms | `https://routefinder.app/legal/terms` |

Defined in:

- iOS/macOS: `ProductLegalDocuments.legalURLBase` in `RouteFinder/Sources/UI/Components/ProductLegalDocuments.swift`
- Android: `LEGAL_PRIVACY_URL` / `LEGAL_TERMS_URL` in `DriverTermsScreen.kt`

**Before App Store submit:** host these files over HTTPS, then set the same URLs in App Store Connect **Privacy Policy URL** (and custom EULA / Terms if used) and update `legalURLBase` / Android constants if the domain differs.

## Publish options (pick one)

### Cloudflare Pages / Netlify / GitHub Pages

1. Create a static site with folder layout `legal/privacy.html` and `legal/terms.html` (or rewrite `/legal/privacy` → `privacy.html`).
2. Upload this `site/` directory (or copy the two HTML files).
3. Attach your custom domain; enable HTTPS.

### nginx (VPS)

```nginx
location /legal/privacy {
  alias /var/www/routefinder-legal/privacy.html;
  default_type text/html;
}
location /legal/terms {
  alias /var/www/routefinder-legal/terms.html;
  default_type text/html;
}
```

### S3 + CloudFront (or similar)

Upload both HTML files with `Content-Type: text/html`, public-read or OAI, HTTPS on the distribution.

## Checks after publish

1. Open both URLs in Safari / Chrome — no login wall.
2. Settings → Legal → **Open full Privacy Policy** / **Terms** in RouteFinder.
3. Paste the same Privacy URL into App Store Connect.
4. Confirm Ltd name, address, and `privacy@` email are no longer placeholders (after solicitor / incorporation).

No analytics or trackers in these drafts — keep it that way for App Review clarity.
