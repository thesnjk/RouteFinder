# Fleet setup guide (non-developer)

Pair a dispatch desk with driver phones over the **office LAN**. No cloud account. Same Wi‑Fi required.

Last updated: 2026-09-04

---

## Before you start

| Requirement | Why |
|-------------|-----|
| Dispatch Mac (or any Mac that can run the fleet server) | Hosts `RouteFinderFleetServer` on port **8080** |
| Driver iPhone(s) on the **same Wi‑Fi** | SSE trip push + Bonjour discovery |
| Optional: Windows PC with Chrome | Web dispatch console |
| Operator HeiGIT ORS key on the **server** (`--ors-key`) | Drivers route without personal API keys |

**LAN / VPN only.** Do not expose port 8080 to the public internet.

---

## 1. Start the fleet server (dispatch Mac)

```bash
cd /Users/admin/Developer/RouteFinder/RouteFinder
swift run RouteFinderFleetServer --port 8080 --ors-key "$ORS_API_KEY"
```

You should see: starting on `0.0.0.0:8080`, Bonjour advertising, and **ORS proxy enabled** when a key is set.

If you see **port already in use**:

```bash
lsof -nP -iTCP:8080 -sTCP:LISTEN
# stop the other process, or pick another port: --port 8081
```

Optional shared secret:

```bash
swift run RouteFinderFleetServer --port 8080 --ors-key "$ORS_API_KEY" --api-key "your-shared-secret"
```

Drivers and web dispatch must use the same API key when auth is enabled.

Daily fair-use caps (defaults 2,000 routes / 2,000 geocodes): `--route-daily-cap` / `--geocode-daily-cap`.

---

## 2. Register a vehicle (Mac dispatch)

1. Open **RouteFinderMac** → **Dispatch** console.
2. Create an organisation (or bootstrap demo fleet).
3. Register / select a vehicle.
4. Show the driver the **QR code** under the vehicle picker (or tap **Copy UUID**).

The QR payload is `routefinder-vehicle:<UUID>` (raw UUID also works when pasting).

---

## 2b. Register a vehicle (web dispatch)

1. On the office PC: follow [web-dispatch-operator-guide.md](web-dispatch-operator-guide.md).
2. Create org → register vehicle.
3. Show the on-screen **QR** (or copy the UUID) to the driver.

---

## 3. Pair the driver (iPhone) — fleet setup wizard

1. Settings → **Fleet & Dispatch** → **Open fleet setup wizard**.
2. Step through: enable remote server → **Discover on LAN** → pick the Mac → **Test connection** → **Scan QR** (or paste UUID) → **Finish**.
3. Confirm HGV mode before the first routed trip.

Manual alternative (same Settings page): toggle remote server, paste URL / API key / vehicle UUID, Test, Save.

---

## 4. Push and rehearse

1. Mac or web: **Push trip**.
2. iPhone toast within ~5 seconds.
3. Driver: **Find route** (uses fleet ORS proxy when configured) → **Rehearse** → **Start**.
4. Optional: walkaround defects appear on the Mac dispatch status panel.

---

## Troubleshooting

| Symptom | Likely cause | Fix |
|---------|--------------|-----|
| Port already in use | Second server instance | `lsof` + kill, or `--port 8081` |
| Failed to fetch in browser | CORS or wrong base URL | Use Vite `/fleet` proxy in dev, or direct `http://<mac-ip>:8080` with fleet CORS enabled |
| Trip never arrives | Wrong vehicle UUID or remote sync off | Re-scan QR; confirm **Use remote fleet server** |
| Orange “add API key” on phone | Fleet proxy off or remote sync off | Restart server with `--ors-key`; finish wizard |
| Discover finds nothing | Different Wi‑Fi / Bonjour blocked | Paste `http://<mac-ip>:8080` manually |

---

## Quick checklist

1. Mac: fleet server with `--ors-key`
2. Mac or web: vehicle UUID + QR
3. iPhone: fleet setup wizard
4. Push → toast → Find route → Rehearse
