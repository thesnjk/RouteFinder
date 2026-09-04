# Web dispatch operator guide (Windows / Linux / Mac office PC)

Browser console for pushing fleet trips without a Mac dispatch window. Talks to **`RouteFinderFleetServer`** on the office LAN.

Last updated: 2026-09-04

---

## What you need

| Item | Notes |
|------|--------|
| Office Mac (or any host) running the fleet server | Same Wi‑Fi as driver phones |
| Chrome / Edge / Safari | Open the web console |
| Driver iPhones | Pair with the vehicle QR from this UI |

**LAN only.** Do not expose port 8080 to the public internet.

---

## 1. Start the fleet server (on the office Mac)

```bash
cd /Users/admin/Developer/RouteFinder/RouteFinder
swift run RouteFinderFleetServer --port 8080 --ors-key "$ORS_API_KEY"
```

- `--ors-key` (or env `ORS_API_KEY`) enables **operator-paid routing** so drivers do not paste HeiGIT keys.
- Optional: `--api-key "shared-secret"` — then enter the same key in the web Connection panel and on driver phones.

You should see: starting on `0.0.0.0:8080`, and optionally “ORS proxy enabled”.

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

**Office PC on the LAN:**

1. On the Mac, build a static bundle: `npm run build` then serve `dist/` on the LAN, **or** keep using `npm run dev -- --host` and open `http://<mac-ip>:5173` from the Windows PC.
2. Set **Server base URL** to `http://<mac-ip>:8080` (CORS is enabled on the fleet server).
3. Tap **Test /health** until the green Connected pill appears.

---

## 3. First-run tour

On first visit, a short tour explains Connect → Org & vehicle → Push trip. You can **Skip** or reopen with **Show tour**.

---

## 4. Create org, vehicle, and QR

1. **Create org** (e.g. “Pilot fleet”).
2. **Register vehicle** (e.g. “Unit 1”).
3. Show the on-screen **QR** to the driver (or **Copy UUID**).
4. Driver: iOS **Settings → Fleet & Dispatch → Open fleet setup wizard** → Discover / Test → **Scan QR** → Finish.

---

## 5. Push a trip

1. Confirm origin / destination labels (demo coords are Norwich → King’s Lynn).
2. **Push trip**.
3. Driver toast within ~5 seconds → Find route → Rehearse.
4. **Driver snapshot** panel polls the active trip (status + physics ETA when the phone reports).
5. **MapLibre** preview shows the stop corridor.

---

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| Failed to fetch | Wrong base URL; use `/fleet` in Vite, or `http://<mac-ip>:8080` with CORS |
| Health not Connected | Fleet server not running; port in use — see `lsof -nP -iTCP:8080 -sTCP:LISTEN` |
| Trip never arrives | Wrong vehicle UUID; re-scan QR; confirm remote fleet sync on the phone |
| ORS proxy off | Restart server with `--ors-key` / `ORS_API_KEY` |
| Drivers asked for HeiGIT key | Enable remote fleet on the phone; ensure ORS proxy is on |

Full pairing detail: [`fleet-setup-guide.md`](fleet-setup-guide.md) · Product overview: [`getting-started.md`](getting-started.md)
