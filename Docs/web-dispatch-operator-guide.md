# Web dispatch operator guide (Windows / Linux / Mac office PC)

Browser console for pushing fleet trips without a Mac dispatch window. Talks to **`RouteFinderFleetServer`** on the office LAN.

Last updated: 2026-09-23

---

## What you need

| Item | Notes |
|------|--------|
| Office Mac (or any host) running the fleet server | Same Wi‑Fi as driver phones |
| Chrome / Edge / Safari | Open the web console |
| Driver iPhones (or Android C2) | Pair with the vehicle QR from this UI |

**LAN / VPN only.** Do not expose port 8080 to the public internet. See [TLS + VPN for remote office](#7-tls--vpn-for-remote-office) if staff work off-site.

---

## 1. Start the fleet server (on the office Mac)

```bash
cd /Users/admin/Developer/RouteFinder/RouteFinder
swift run RouteFinderFleetServer --port 8080 --ors-key "$ORS_API_KEY"
```

- `--ors-key` (or env `ORS_API_KEY`) enables **operator-paid routing and Pelias geocode** so drivers and web dispatch do not paste HeiGIT keys.
- Optional forecast fuse (no driver TomTom / OpenWeather keys): `--tomtom-key` / `TOMTOM_API_KEY` and `--openweather-key` / `OPENWEATHER_API_KEY`.
- Optional: `--api-key "shared-secret"` — then enter the same key in the web Connection panel and on driver phones.

You should see: starting on `0.0.0.0:8080`, “ORS proxy enabled”, and optionally “TomTom flow proxy enabled” / “OpenWeather forecast proxy enabled”.

After **Test /health**, the Connection panel shows ORS metering plus TomTom / OpenWeather on/off from `/v1/proxy/status`.

Find the Mac’s LAN IP (System Settings → Network), e.g. `192.168.1.10`.

---

## 2. Open the web console

**Development (same Mac as Vite):**

```bash
cd /Users/admin/Developer/RouteFinder/web-dispatch
npm install
npm run dev
```

Open <http://127.0.0.1:5173> — default base URL is `/fleet` (Vite proxies to `:8080`).

**Office PC on the LAN (dev server):**

1. On the Mac: `npm run dev -- --host`
2. From the Windows / office PC open `http://<mac-ip>:5173`
3. Set **Server base URL** to `http://<mac-ip>:8080` (CORS is enabled on the fleet server)
4. Tap **Test /health** until the green **Connected** pill appears

For a production-style static build on the LAN, see [Static hosting on LAN](#6-static-hosting-on-lan).

---

## 3. First-run tour

On first visit, a short tour explains Connect → Org & vehicle → Push trip → Walkaround defects. You can **Skip** or reopen with **Show tour**.

---

## 4. Create org, vehicle, and QR

1. **Create org** (e.g. “Pilot fleet”).
2. **Register vehicle** (e.g. “Unit 1”).
3. Show the on-screen **QR** to the driver (or **Copy UUID**).
4. Driver: iOS **Settings → Fleet & Dispatch → Open fleet setup wizard** → Discover / Test → **Scan QR** → Finish.

---

## 5. Geocode stops and push a trip

Address search uses the fleet Pelias proxy (`GET /v1/proxy/pelias/v1/search`). The office Mac must start the fleet server with **`--ors-key`** (operator-paid). Usage appears in the Connection panel as geocode counts from `/v1/proxy/status`.

1. **Origin** — type a UK place (e.g. `Norwich`) and pick a suggestion. Lat/lon appear under the field.
2. **Destination** — same for the end stop (e.g. `King's Lynn`).
3. Optional **job brief** — Gross weight (kg), ADR class, and per-stop time windows (local datetime → ISO on push). Drivers apply weight/ADR on intake; late-ETA fuse uses windows when present.
4. **Push trip** stays disabled until both stops have coordinates.
5. Driver toast within ~5 seconds → **zero-tap intake** on C2 (SSE applies stops + auto Find route). No Accept tap on the navigator path; legacy C1 home Accept is demo-only.
6. **Driver snapshot** panel polls the active trip (status, physics ETA, **Last GPS** when the phone publishes).
7. When the driver saves a walkaround with defects, an orange **Walkaround defects** card appears (optional **Download PDF** if the phone attached a report). A one-line toast fires when new defects arrive on poll.
8. **MapLibre** preview shows A/B stops and a live **driver** pin when GPS is present.

Timed demo: [`demo-superiority-script.md`](demo-superiority-script.md).

---

## 6. Static hosting on LAN

Serve the built SPA so office PCs do not need Vite:

```bash
cd /Users/admin/Developer/RouteFinder/web-dispatch
npm install
npm run build
npx serve -s dist -l 5173 --host
```

Or point nginx / IIS at `web-dispatch/dist/` on the office Mac.

Windows PC opens `http://<mac-ip>:5173` and sets **Server base URL** to `http://<mac-ip>:8080` (or `https://…` if TLS is enabled on the fleet server).

---

## 7. TLS + VPN for remote office

For staff outside the office LAN:

1. **VPN first** — WireGuard or OpenVPN into the office network so phones and PCs reach the Mac’s private IP. Prefer this over opening ports on the router.
2. **TLS on the fleet server** — start with certificate paths (see server CLI):

   ```bash
   swift run RouteFinderFleetServer \
     --port 8443 \
     --tls-cert /path/to/cert.pem \
     --tls-key /path/to/key.pem \
     --ors-key "$ORS_API_KEY"
   ```

3. Point web dispatch and driver apps at `https://<office-host>:8443` (or the VPN-reachable hostname).
4. **Never** forward port 8080/8443 to the public internet without VPN + auth (`--api-key`).

Security notes: [`fleet-e2e-qa.md`](fleet-e2e-qa.md).

---

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| Failed to fetch | Wrong base URL; use `/fleet` in Vite, or `http://<mac-ip>:8080` with CORS |
| Health pill red / Offline | Fleet server not running; port in use — see `lsof -nP -iTCP:8080 -sTCP:LISTEN` |
| Geocode search errors | Restart server with `--ors-key`; check geocode counts in Connection panel (`/v1/proxy/status`). At daily cap the UI shows *Fleet geocode daily cap reached…* (`fleetProxyUserMessage`) — raise the proxy budget or wait until tomorrow; see [`unit-economics.md`](unit-economics.md) |
| Trip never arrives | Wrong vehicle UUID; re-scan QR; confirm remote fleet sync on the phone |
| ORS proxy off | Restart server with `--ors-key` / `ORS_API_KEY` |
| Drivers asked for HeiGIT key | Enable remote fleet on the phone; ensure ORS proxy is on |
| No Last GPS / driver pin | Driver must **Start** navigation (or sim) and grant location; wait ~20–60 s for snapshot publish — C2 has no Accept step |
| Walkaround saved but no defect card | Confirm active trip is selected; phone published `latestInspectionSummary` with `defectCount > 0`; wait one 5 s poll — see [`demo-superiority-script.md`](demo-superiority-script.md) |

Full pairing detail: [`fleet-setup-guide.md`](fleet-setup-guide.md) · Verification script: [`phase4-dispatch-verification.md`](phase4-dispatch-verification.md) · Product overview: [`getting-started.md`](getting-started.md)
