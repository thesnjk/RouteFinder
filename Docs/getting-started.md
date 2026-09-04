# Getting started with RouteFinder

Pick your role. Each path assumes you have not used RouteFinder before.

Last updated: 2026-09-04

---

## I'm a driver (iPhone)

1. Install **RouteFinderApp** from Xcode (`RouteFinderApp` scheme → your iPhone) or the pilot TestFlight build.
2. Create a local account (or sign in). Accept **Driver Terms** on first launch.
3. Choose **Car** or **HGV** when asked (you can change later in Settings / map menu).
4. **Fleet pilots (preferred):** Settings → **Fleet & Dispatch** → **Open fleet setup wizard** → Discover office server → Test → Scan vehicle QR from Mac/web dispatch. With the office server started with `--ors-key`, you do **not** need a personal HeiGIT key.
5. **Solo / no fleet server:** Settings → API keys → paste a HeiGIT [OpenRouteService](https://openrouteservice.org/) key → **Save**.
6. Plan a first route (search or map pin) → **Find route** → **Rehearse Route** → **Start**.

More: [user-guide-simulation.md](user-guide-simulation.md) · Fleet pairing: [fleet-setup-guide.md](fleet-setup-guide.md)

---

## I'm a dispatcher (Mac)

1. Open `RouteFinderApp.xcodeproj` → scheme **RouteFinderMac** → Run.
2. Start the fleet server on the same Mac (same Wi‑Fi as drivers):

```bash
cd /Users/admin/Developer/RouteFinder/RouteFinder
swift run RouteFinderFleetServer --port 8080 --ors-key "$ORS_API_KEY"
```

3. In the app, open the **Dispatch** console window.
4. Create an organisation and register a vehicle (or use demo bootstrap).
5. Show the driver the **vehicle QR** (or copy the UUID).
6. Push a 2-stop trip. The driver iPhone should toast within ~5 seconds.

Full pairing steps: [fleet-setup-guide.md](fleet-setup-guide.md)

---

## I'm a dispatcher (Windows / Linux office PC)

Use the browser console against the Mac fleet server on the office LAN:

1. Someone starts `RouteFinderFleetServer` on the office Mac (port 8080, preferably with `--ors-key`).
2. Follow [web-dispatch-operator-guide.md](web-dispatch-operator-guide.md).
3. Create org → register vehicle → show drivers the QR → push trip.

---

## What RouteFinder is (and is not)

**Is:** UK HGV-aware routing, physics rehearsal, advisory HOS / layby, LAN fleet dispatch, walkaround → dispatch handoff.

**Is not (yet):** Hosted multi-tenant SaaS portal, full Android navigator, production CarPlay on personal teams, telematics / remote VU replacement.

**Do not promise:** hosted SaaS portal, CarPlay, Android Auto, full Android navigator, remote VU download, 24/7 support.

---

## Doc index

| Doc | Audience |
|-----|----------|
| [fleet-setup-guide.md](fleet-setup-guide.md) | Pairing Mac ↔ iPhone ↔ web |
| [web-dispatch-operator-guide.md](web-dispatch-operator-guide.md) | Windows office PCs |
| [pilot-fleet-pack.md](pilot-fleet-pack.md) | Pilot terms + API contract |
| [operator-next-steps.md](operator-next-steps.md) | Your weekly checklist |
| [unit-economics.md](unit-economics.md) | API metering / fair-use |
