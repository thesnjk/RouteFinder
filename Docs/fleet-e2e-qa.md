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

## Part B — Manual LAN E2E (Mac dispatch + iPhone driver)

### Prerequisites

- Dispatch Mac and driver iPhone on the **same Wi‑Fi or LAN**
- RouteFinder built for macOS and iOS (Xcode or `swift run`)
- Optional: HeiGIT ORS API key in Settings for live HGV route find
- Optional: `--api-key` on the fleet server when testing shared-secret auth

### Step-by-step

| Step | Dispatch Mac | Driver iPhone |
|---|---|---|
| 1 | Start fleet server: `cd RouteFinder && swift run RouteFinderFleetServer --port 8080` | — |
| 2 | Open RouteFinderMac → **Dispatch Console** → create org + register vehicle; note the **vehicle UUID** | — |
| 3 | — | **Settings → Fleet dispatch → Discover fleet servers on LAN** |
| 4 | — | Select the Mac entry (or enter `http://<dispatch-mac-ip>:8080` manually). Tap **Test fleet connection**. Paste **Fleet vehicle UUID** → **Save vehicle id**. Enable remote fleet server if prompted. |
| 5 | Push a 2–3 stop trip from Dispatch Console | Trip toast/banner within **~5 s** via SSE (`GET /v1/vehicles/{id}/events`); fallback poll every 30 s if SSE drops |
| 6 | — | Accept dispatch → **Find route** → **Rehearse Route** |
| 7 | — | Open trip brief share menu → verify plain text **and** PDF include stops, physics ETA, layby/HOS blocks where applicable |
| 8 | Dispatch console shows updated trip status / physics ETA snapshot from driver publish | — |

### API surface (for curl debugging)

| Method | Path | Purpose |
|---|---|---|
| GET | `/health` | Server liveness |
| POST | `/v1/orgs` | Create org |
| POST | `/v1/vehicles` | Register vehicle |
| POST | `/v1/trips` | Push trip to driver |
| GET | `/v1/vehicles/{id}/active-trip` | Poll active trip |
| GET | `/v1/vehicles/{id}/events` | SSE stream (`tripPushed`, heartbeat) |
| PUT | `/v1/trips/{id}/snapshot` | Driver physics ETA + layby snapshot |

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

When two devices or LAN are unavailable:

1. Open RouteFinder on one device (Mac or iPhone).
2. **Settings → Fleet dispatch → Accept demo dispatch**
3. **Find route** → **Rehearse Route**
4. Share trip brief (text + PDF)

This seeds a local three-stop UK job via `DiskFleetStore.seedDemoThreeStopJob()` and validates dispatch UX without network sync.

---

## Related docs

- [README — Fleet LAN server](../README.md#fleet-lan-server-multi-device-sync)
- [Phase 20 verification — scenario 6b](phase20-verification.md)
- [Competitive gap matrix — Phase 27 backlog](competitive-gap-matrix.md)
