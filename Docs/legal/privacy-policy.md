# RouteFinder Privacy Policy

**Status:** Draft for solicitor review — not legal advice.  
**Last updated:** 2026-09-17  
**Controller:** *[Ltd company name]* (replace after incorporation) — registered address: *[registered address]*.

Contact for privacy requests: `privacy@[YOUR_DOMAIN]` (replace before App Store / paid pilots).

Hosted copy (after you publish): `https://routefinder.app/legal/privacy` — replace domain to match [`site/README.md`](site/README.md).

---

## 1. Scope

This policy describes how RouteFinder processes personal data when you use:

- RouteFinder **iOS** and **macOS** apps
- **RouteFinderFleetServer** on a local network (LAN)
- **Web dispatch** console (`web-dispatch`) on Operator LAN or VPN
- **Android** fleet driver app (trip receive and HGV navigation where enabled)
- Optional **hosted gateway** (VPS) for remote depots — see [`../hosted-gateway-deployment.md`](../hosted-gateway-deployment.md)
- Pilot programmes under a signed pilot agreement

RouteFinder is primarily an **on-device / on-LAN** product. Default fleet trip and inspection data stay on Operator devices and the Operator’s LAN (or Operator-controlled hosted gateway) store.

---

## 2. Data we may process

| Category | Examples | Typical location |
|----------|----------|------------------|
| Account | Local username / password hash (Keychain / Keystore) | Device |
| Vehicle | Registration plate, dimensions, HGV profile | Device / fleet store |
| Trip | Stops, status, physics ETA, layby / HOS advice | Device / fleet store |
| Location snapshots | Periodic lat/lon + timestamp on `FleetTripSnapshot` for dispatch map pin | Device → fleet store |
| Telematics (read-only) | Partner CSV import; optional `POST /v1/telematics/ingest` pings | Operator device / fleet store |
| Inspection | Walkaround defects, optional PDF | Device / fleet store |
| Usage metering | ORS / Pelias / TomTom / weather API call counts | Device / fleet / hosted gateway |
| Technical | Crash logs you choose to share; OS identifiers | Device / Apple / Google |
| Pilot feedback | Forms, emails, meeting notes | Provider systems |

We do **not** sell personal data. We may use **anonymised** pilot feedback to improve the product.

**Not legal VU / ELD:** Telematics CSV and ingest stubs display last-known partner positions for dispatch convenience. They are **not** a digital tachograph, Vehicle Unit download, or certified telematics compliance product.

**UK toll advisories:** Named toll hints along a route are **indicative** authored advisories — not live tariff tables or billing data.

---

## 3. Lawful bases (UK GDPR)

- **Contract** — provide routing, dispatch, and pilot services you request
- **Legitimate interests** — product security, abuse prevention, improving advisory features
- **Consent** — where you tick privacy consent at signup, or optional analytics (if introduced later)
- **Legal obligation** — where required by law

---

## 4. Third-party processors / APIs

When you (or your Operator) configure API keys or enable the fleet / hosted **ORS/Pelias proxy**, requests may leave the device to:

- HeiGIT OpenRouteService (routing / geocoding / matrix) — often via Operator-paid proxy with **fair-use daily caps**
- Optional TomTom traffic services
- Optional OpenWeather / WeatherKit
- OpenStreetMap Overpass (lane tags / roadworks where enabled)
- Map tile / style providers shown in map attribution
- Optional parking partner sites (TRAVIS / SNAP) when the driver opens deep links — those sites process data under their own policies

Their processing is governed by their terms. You control whether keys are stored and which services are enabled.

Apple App Store / Google Play process purchases and distribution under their policies when applicable.

---

## 5. Retention

- Local account and settings: until you delete the app or clear Keychain / Keystore data
- LAN / hosted fleet store: controlled by the Operator who runs `RouteFinderFleetServer` or the hosted gateway
- Telematics import / ingest files: Operator-controlled; capped ring buffers on ingest stubs
- Pilot correspondence: retained as needed for the pilot and legitimate business records, then deleted or anonymised

---

## 6. Your rights (UK)

You may request access, rectification, erasure, restriction, portability, and object to certain processing. Contact the privacy email above. You may complain to the [ICO](https://ico.org.uk/).

---

## 7. Children

RouteFinder is intended for professional drivers and fleet operators, not for children under 16.

---

## 8. International transfers

Default LAN operation keeps data on Operator networks. If Operator enables remote URL / TLS or a hosted gateway, Operator chooses the hosting location and accepts that network risk (see pilot agreement and Terms).

---

## 9. Changes

We will update the “Last updated” date and, for material changes, notify in-app or by email to pilot contacts.

---

## 10. Driver Terms relationship

In-app **Driver Terms** ([`driver-terms.md`](driver-terms.md)) cover routing liability and advisory use. This Privacy Policy covers personal data. Both apply.
