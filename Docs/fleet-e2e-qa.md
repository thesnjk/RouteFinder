# Fleet E2E QA playbook

Repeatable verification for RouteFinder fleet dispatch: automated HTTP/SSE/Bonjour smoke on Mac, manual Mac↔iPhone LAN checklist, and a single-device demo fallback.

Last updated: 2026-08-28 (Phase 27c)

---

## Part A — Automated smoke (Mac, ~2 min)

From the Swift package directory:

```bash
cd RouteFinder
chmod +x Scripts/fleet-e2e-smoke.sh
./Scripts/fleet-e2e-smoke.sh
```

Or with an explicit Xcode developer directory:

```bash
DEVELOPER_DIR=/Users/admin/Downloads/Xcode-beta.app/Contents/Developer ./Scripts/fleet-e2e-smoke.sh
```

### What the script covers

| Area | Test(s) |
|---|---|
| Health + org/vehicle/trip push + snapshot | `httpFleetStoreSyncsTripsOverLANServer` |
| Fleet store factory (local vs remote) | `fleetStoreFactoryUsesDiskStoreByDefault`, `fleetStoreFactoryUsesHTTPStoreWhenRemoteEnabled` |
| SSE `tripPushed` delivery | `fleetSSEClientReceivesTripPushedEvent`, `fleetSSEConnectionSurvivesHeartbeatInterval` |
| SSE auth rejection | `fleetSSEEndpointRejectsMissingAPIKeyWhenConfigured` |
| Bonjour URL + TLS TXT helpers | `fleetBonjour*` |
| Stop role assignment on push | `createAndPushTripAssignsStopRoles` |
| End-to-end push → SSE → snapshot → trip brief | `fleetE2EWorkflowPushSnapshotAndSSE` |

Exit code `0` = all targeted tests passed.

---

## Part B — Manual LAN E2E (web-dispatch desk + iPhone driver)

### Prerequisites

- Office Mac and driver iPhone on the **same Wi‑Fi or LAN**
- RouteFinder built for iOS (Xcode); Mac map app optional for simulation
- Operator HeiGIT ORS key on the **server** (`--ors-key`) for live HGV route find without a driver HeiGIT key
- **Recommended for pilots:** `--api-key` on the fleet server; paste the same secret into **web-dispatch Bearer** / wizard

### Step-by-step

| Step | Desk (web-dispatch) | Driver iPhone |
|---|---|---|
| 1 | Start fleet server: `cd RouteFinder && swift run RouteFinderFleetServer --port 8080 --ors-key "$ORS_API_KEY" --api-key "$FLEET_API_KEY"` | — |
| 2 | `cd web-dispatch && npm run dev` → http://127.0.0.1:5173 → Bearer Connected → **Bootstrap demo fleet** (or create org + vehicle). QR under selected vehicle. Copy LAN URL for phone if Discover will fail. | — |
| 3 | — | **Settings → Fleet & Dispatch → Open fleet setup wizard** (or Driver setup → Pair with fleet) |
| 4 | — | Discover on LAN **or** paste LAN URL. Tap **Test connection**. Enter the same **Fleet API key** as `--api-key`. **Scan QR** (or paste vehicle UUID) → Save → Finish. |
| 5 | **Push trip** (Norwich → King's Lynn is the default draft; Load optional reset) | Trip toast/banner within **~5 s** via SSE (`GET /v1/vehicles/{id}/events`); fallback poll every 30 s if SSE drops |
| 6 | — | Toast **New dispatch received — loading route…** → stops apply → auto **Find route** (zero-tap intake). Then **Rehearse Route** if desired. Do **not** tap Settings **Load offline demo job** while paired — that seeds a local job and breaks the vehicle UUID. |
| 7 | — | Open trip brief share menu → verify plain text **and** PDF include stops, physics ETA, layby/HOS blocks where applicable |
| 8 | web-dispatch shows updated trip status / physics ETA / Last GPS snapshot from driver publish | — |
| 9 | web-dispatch shows **Walkaround defects** card with defect count; download PDF when driver saved inspection with defects | Complete zoned walkaround with ≥1 defect → **Save** on **driver iPhone** (not Mac Settings) |

**After run:** mark P49b-2 + Fleet Part B rows in [`phase20-verification.md`](phase20-verification.md) Pass/Fail. Part A automated smoke last verified **Pass** local 2026-09-29 (`fleet-e2e-smoke.sh` **14/14**).

Last updated: 2026-09-30 (Primary desk = web-dispatch; Mac app = simulation)

Native Mac **Dispatch Console** remains as legacy/iPad fallback only (Settings → Advanced).

### API surface (for curl debugging)

| Method | Path | Purpose |
|---|---|---|
| GET | `/health` | Server liveness |
| POST | `/v1/orgs` | Create org |
| POST | `/v1/vehicles` | Register vehicle |
| POST | `/v1/trips` | Push trip to driver |
| GET | `/v1/vehicles/{id}/active-trip` | Poll active trip |
| GET | `/v1/vehicles/{id}/events` | SSE stream (`tripPushed`, heartbeat) |
| PUT | `/v1/trips/{id}/snapshot` | Driver physics ETA + layby + optional inspection summary/PDF base64 |

Bonjour service type: `_routefinder-fleet._tcp`.

### Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| Discover finds nothing | Firewall, different subnet, Bonjour blocked | Allow incoming on port 8080; or start server with manual URL (`--no-bonjour` on server is fine if URL is typed) |
| Test connection fails | Wrong IP/port, server not running | Confirm `curl http://<mac-ip>:8080/health` returns `{"ok":true,...}` |
| Trip never arrives on phone | Vehicle UUID mismatch | UUID in Settings must match dispatch console vehicle |
| 401 on SSE or REST | API key mismatch | Same key in server `--api-key` and Settings **Fleet API key** |
| Trip arrives but no route | Missing ORS key | Add HeiGIT key in Settings or use demo stops with offline tiles |

**LAN / VPN only.** Do not expose the fleet server to the public internet without proper network controls.

---

## Part C — Single-device fallback (no server)

When two devices or LAN are unavailable (**remote fleet must be off**):

1. Open RouteFinder on one device (Mac or iPhone).
2. **Settings → Fleet dispatch → Load offline demo job (no LAN)**
3. **Find route** → **Rehearse Route**
4. Share trip brief (text + PDF)

This seeds a local three-stop UK job via `DiskFleetStore.seedDemoThreeStopJob()` and validates dispatch UX without network sync. If remote fleet is paired, the control refuses so it cannot overwrite the live vehicle UUID.

---

## Related docs

- [README — Fleet LAN server](../README.md#fleet-lan-server-multi-device-sync)
- [Phase 20 verification — scenario 6b](phase20-verification.md)
- [Competitive gap matrix — Phase 27 backlog](competitive-gap-matrix.md)
