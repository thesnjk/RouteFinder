# Buyer Personas — UK HGV (2026)

Two primary personas for competitive positioning (equal weight in Phase 26 research and gap ranking), plus two secondary personas for Android / hosted surface scoring.

---

## Persona 1: UK owner-operator ("Dave")

| Attribute | Detail |
|---|---|
| **Fleet size** | 1 tractor unit (+ trailer) |
| **Typical run** | UK long-haul (e.g. Norwich ↔ Scotland, Midlands ↔ ports) |
| **Tech** | Personal iPhone; maybe older TomTom or phone mount |
| **Budget sensitivity** | High — avoids recurring nav subscriptions |
| **Legal pressure** | EU 561 breaks, LEZ/CAZ in cities, DVSA walkaround |

### Jobs to be done

1. Route that respects **height/weight/hazmat** without manual guesswork.
2. Know **where to break** before hours run out — without paid parking booking.
3. **Avoid LEZ fines** or enter knowingly with compliant vehicle.
4. **Rehearse** difficult legs (grades, kinetic risk) before leaving yard.
5. Offline or degraded-signal resilience on rural A-roads.

### Must-haves

- Truck constraint routing
- Break/layby guidance
- LEZ awareness
- Voice + map guidance at junctions

### Deal-breakers

- Routes sending 16t through village low bridge
- No break planning on long legs
- Surprise LEZ entry without warning
- £10+/month subscription with no differentiation

### Default competitor today

**Sygic Truck** (offline + LEZ + familiar) or **CoPilot** if inherited from previous employer.

### Why RouteFinder wins (post–Phase 26)

- **Physics rehearsal** — unique pre-trip sim
- **Break Now** — CoPilot-parity one-tap layby (no TRAVIS fee)
- **UK plate → profile** — RegCheck + DVLA chain
- **$0** — no Sygic subscription

### Why RouteFinder loses (honest)

- No CarPlay in personal-team builds
- Smaller offline map footprint than Sygic Europe pack
- No paid parking reservation network

---

## Persona 2: Small fleet operator ("Sarah")

| Attribute | Detail |
|---|---|
| **Fleet size** | 2–20 rigids/artics |
| **Role** | Owner or transport manager; 1 office Mac/iPad |
| **Tech** | Mix of driver phones; may have Geotab/Samsara for compliance |
| **Budget sensitivity** | Medium — pays for compliance/telematics, resists nav per-seat tax |
| **Legal pressure** | Same as Dave + fleet audit trail, dispatch proof |

### Jobs to be done

1. **Push trip** to driver with stops and constraints.
2. **Physics ETA** back to depot/customer (not inflated web ETA).
3. **Trip brief** PDF for customer or internal risk review.
4. Discover fleet server on **office LAN** without IT project.
5. Optional: layby prediction on active trip for break compliance.

### Must-haves

- Multi-stop routing + dispatch
- Driver notification on trip change
- Shareable trip documentation

### Deal-breakers

- Per-driver nav SaaS quote for 15 seats
- No way to push route without WhatsApp PDF
- ETA that ignores vehicle physics/load

### Default competitor today

**CoPilot + Account Manager** or **TomTom WEBFLEET** add-on; telematics from **Samsara/Geotab** for tacho.

### Why RouteFinder wins (post–Phase 26)

- **$0 LAN fleet server** — Bonjour + SSE + API key/TLS
- **Native macOS dispatch** + iPhone driver toast
- **Trip brief PDF** with route map snapshot
- **Physics ETA** on dispatch panel

### Why RouteFinder loses (honest)

- No hosted web portal for 50+ vehicles
- No remote VU download (telematics stays separate system)
- No Android Auto for mixed-device fleets

---

## Persona 3: Android-heavy small fleet ("Priya")

| Attribute | Detail |
|---|---|
| **Fleet size** | 3–12 rigids; mixed phones, **Android-primary** drivers |
| **Role** | Transport manager; cares about cab UX parity with iOS office demos |
| **Tech** | Android fleet driver + LAN/hosted desk; may ask for Android Auto later |
| **Budget sensitivity** | Medium — will not buy CoPilot AA seats if RF Android is “good enough” |

### Jobs to be done

1. Same fuse / layby / LEZ / Can-I-drive honesty as iOS demos.
2. Hands-free rest prompts without leaving the map.
3. Optional later: Android Auto (product-gated until renewals demand it).

### Weighted emphasis

Android C2 depth, PTT + proactive layby voice, roadworks-in-fuse, HOS/tacho import; AA/offline remain gated.

---

## Persona 4: Hosted-remote desk ("Omar")

| Attribute | Detail |
|---|---|
| **Fleet size** | 5–25; **no office Mac on the depot LAN** |
| **Role** | Owner operating from home / second site |
| **Tech** | `hosted-gateway` + web-dispatch over HTTPS; drivers on iOS or Android |
| **Budget sensitivity** | Medium — pays for reachable desk, resists per-seat nav SaaS |

### Jobs to be done

1. Push trips and see GPS age without Bonjour/LAN.
2. Fair-use / auth clarity when caps hit.
3. Multi-depot later (billing UI residual vs CoPilot Account Manager).

### Weighted emphasis

hosted-gateway + web-dispatch; SF dispatch rows split LAN vs hosted in scorecard footnotes.

---

## Persona → feature map

| Feature | Dave (OO) | Sarah (SF) | Priya (Android) | Omar (Hosted) |
|---|---|---|---|---|
| Break Now | **Critical** | Useful | **Critical** | Useful |
| LEZ v2 | **Critical** | Important | **Critical** | Important |
| Lane voice | Important | Nice-to-have | Important | Nice-to-have |
| Fleet SSE dispatch | — | **Critical** | Important | **Critical** (hosted) |
| Trip brief PDF | Useful | **Critical** | Useful | **Critical** |
| Physics rehearsal | **Critical** | Important | Important | Useful |
| CarPlay / AA | Wanted | Wanted — deferred | AA wanted — gated | — |
| Tacho / Can-I-drive | Important | Important | **Critical** | Important |

See [`competitive-feature-scorecard.md`](competitive-feature-scorecard.md) for weighted scoring.
