# Getting started with RouteFinder

Pick your role **in the app** after sign-in (Getting started sheet). Each path below is a stranger test — no prior RouteFinder knowledge required.

Last updated: 2026-09-19

---

## In-app role picker (all platforms)

After authentication, RouteFinder shows **Getting started** with three cards:

| Role | Who | What happens next |
|------|-----|-------------------|
| **Driver** | iPhone / in-cab | Driver Terms → Car or HGV → Pair with fleet / Solo |
| **Dispatcher (Mac)** | Office Mac | Driver Terms → fleet server one-liner + **Open Dispatch Console** |
| **Office PC** | Windows/Linux desk | LAN URL template + web-dispatch quick steps |

Re-open anytime: **Settings → Getting started**.

---

## I'm a driver (iPhone) — stranger test

1. Install **RouteFinderApp** (`RouteFinderApp` scheme → your iPhone) or TestFlight.
2. Create a local account (or sign in).
3. **Pick Driver** on Getting started.
4. Accept **Driver Terms** → choose **Car** or **HGV**.
5. On **Driver setup**:
   - **Fleet pilots:** tap **Pair with fleet** → fleet wizard opens with **Use remote fleet server** already on → choose **Office LAN** (Discover) or **Hosted (HTTPS)** → Test → Scan vehicle QR. With the server/gateway started with an ORS key, you do **not** need a personal HeiGIT key.
   - **Solo:** tap **Solo driver** → Settings opens on **API Keys** → paste a HeiGIT [OpenRouteService](https://openrouteservice.org/) key → **Save**.
6. Plan a first route (search or map pin) → **Find route** → **Rehearse Route** → **Start**.

If the orange map banner says **Add API key or Pair with fleet**, use Driver setup / Settings — it hides once a local ORS key **or** fleet remote URL is configured.
More: [user-guide-simulation.md](user-guide-simulation.md) · Fleet pairing: [fleet-setup-guide.md](fleet-setup-guide.md) · Device QA: [phase1-device-checklist.md](phase1-device-checklist.md)

---

## I'm a dispatcher (Mac) — stranger test

1. Open `RouteFinderApp.xcodeproj` → scheme **RouteFinderMac** → Run → sign in.
2. **Pick Dispatcher (Mac)** on Getting started.
3. Accept Driver Terms if prompted.
4. On the Dispatcher sheet: **Copy server command**, then in Terminal (RouteFinder package directory):

```bash
cd /Users/admin/Developer/RouteFinder/RouteFinder
swift run RouteFinderFleetServer --port 8080 --ors-key "$ORS_API_KEY"
```

5. Tap **Open Dispatch Console** (or Window → Dispatch Console).
6. Create an organisation and register a vehicle (or demo bootstrap).
7. Show the driver the **vehicle QR** (or copy the UUID).
8. Push a 2-stop trip. The driver iPhone should toast within ~5 seconds.

Full pairing steps: [fleet-setup-guide.md](fleet-setup-guide.md)

---

## I'm a dispatcher (Windows / Linux office PC) — stranger test

1. On a Mac or iPad with RouteFinder: sign in → **Pick Office PC**.
2. Note the URL template `http://<office-mac-ip>:8080` (copy from the sheet).
3. Someone starts `RouteFinderFleetServer` on the office Mac (port 8080, preferably with `--ors-key`).
4. On the office PC: open Chrome → follow [web-dispatch-operator-guide.md](web-dispatch-operator-guide.md).
5. Create org → register vehicle → show drivers the QR → push trip.

---

## I'm an Android fleet driver (C2) — stranger test

1. Build/install `android-fleet-driver` APK (`./gradlew :app:assembleDebug`).
2. Accept **Driver Terms** → onboarding → **Fleet setup** (Discover / URL → Test /health → Scan QR).
3. On the **navigation map**: search origin/destination → **Find route** (fleet ORS proxy) → **Start** (metric voice) or **Rehearse**.
4. When a trip is pushed: route auto-loads → Start → GPS pin updates Mac/web.

See [android-c2-gate.md](android-c2-gate.md) and [phase6b-android-nav-verification.md](phase6b-android-nav-verification.md).

---

## What RouteFinder is (and is not)

**Is:** UK HGV-aware routing, physics rehearsal, advisory HOS / layby, LAN or hosted fleet dispatch, walkaround → dispatch handoff, operator-paid ORS proxy for paired drivers.

**Is not (yet):** Hosted multi-tenant SaaS admin / billing UI, Android Auto, telematics / remote VU replacement. Android C2 MVP nav ships in `android-fleet-driver` (fleet proxy). Production CarPlay requires a paid Apple Developer team — see [`carplay-weatherkit-restore.md`](carplay-weatherkit-restore.md) and [`phase5-carplay-verification.md`](phase5-carplay-verification.md). Remote depots use the minimal hosted gateway ([`hosted-gateway-deployment.md`](hosted-gateway-deployment.md)), not a full SaaS portal.

**Do not promise:** full SaaS portal, Android Auto, remote VU download, 24/7 support. Do not claim CarPlay on personal-team builds.

---

## Doc index

| Doc | Audience |
|-----|----------|
| [fleet-setup-guide.md](fleet-setup-guide.md) | Pairing Mac ↔ iPhone ↔ web |
| [hosted-gateway-deployment.md](hosted-gateway-deployment.md) | VPS HTTPS gateway for remote depots |
| [phase7-hosted-verification.md](phase7-hosted-verification.md) | Hosted relay exit-gate checklist |
| [web-dispatch-operator-guide.md](web-dispatch-operator-guide.md) | Windows office PCs |
| [phase1-device-checklist.md](phase1-device-checklist.md) | 30-minute Mac + iPhone QA |
| [phase4-platform-parity-verification.md](phase4-platform-parity-verification.md) | Engineering Phase 4: CarPlay + Android C2 + hosted gates |
| [demo-superiority-script.md](demo-superiority-script.md) | 2-minute push → rehearse → pin → walkaround demo |
| [phase6-performance-verification.md](phase6-performance-verification.md) | Hotspot measurements (lane cap, offline progress, web map) |
| [phase7-device-simulator-verification.md](phase7-device-simulator-verification.md) | Eng Phase 7: C3/C5/C6/C7 UITest P0 gate |
| [phase20-verification.md](phase20-verification.md) | Product + engineering excellence verification ledger |
| [phase5-carplay-verification.md](phase5-carplay-verification.md) | Paid-team CarPlay + fleet handoff QA |
| [phase6-android-c1-verification.md](phase6-android-c1-verification.md) | Android C1 trip receive QA |
| [phase6b-android-nav-verification.md](phase6b-android-nav-verification.md) | Android C2 HGV nav QA |
| [pilot-fleet-pack.md](pilot-fleet-pack.md) | Pilot terms + API contract |
| [operator-next-steps.md](operator-next-steps.md) | Your weekly checklist |
| [unit-economics.md](unit-economics.md) | API metering / fair-use |
