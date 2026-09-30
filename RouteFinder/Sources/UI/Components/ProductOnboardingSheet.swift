import Contracts
import SwiftUI

/// First-launch and Settings re-entry sheet explaining core RouteFinder workflows.
struct ProductOnboardingSheet: View {
    /// When true, the driver must accept the liability disclaimer before dismissing.
    var requireLiabilityAcceptance: Bool = false
    /// Called after flags are saved when shown as a launch overlay (Environment `dismiss` is a no-op there).
    /// Settings sheet presentation omits this and relies on `dismiss()` instead.
    var onFinished: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @State private var liabilityAccepted = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: RFSpacing.lg) {
                    headerSection
                    rehearseSection
                    playSection
                    trafficSection
                    laneSection
                    vehicleSection
                    walkaroundSection
                    breakNowSection
                    lezSection
                    fleetSection
                    searchLanguageSection
                    quickReferenceSection
                    if requireLiabilityAcceptance {
                        liabilitySection
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(RFSpacing.lg)
                .padding(.bottom, RFSpacing.xl)
            }
            .navigationTitle("How RouteFinder works")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Got it", action: markSeenAndDismiss)
                        .modifier(GlassButton())
                        .disabled(requireLiabilityAcceptance && !liabilityAccepted)
                }
            }
        }
        .interactiveDismissDisabled(requireLiabilityAcceptance && !liabilityAccepted)
        #if os(macOS)
        .frame(width: 520, height: 640)
        #endif
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: RFSpacing.sm) {
            Label("Route simulation and navigation", systemImage: "map.fill")
                .font(RFFont.sectionTitle)
                .foregroundStyle(RFColor.route)

            Text("RouteFinder combines HGV-aware routing, physics rehearsal, and live map playback. This guide covers the controls you will use after calculating a route.")
                .font(RFFont.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(RFSpacing.md)
        .glassPanel(cornerRadius: 14)
    }

    private var rehearseSection: some View {
        onboardingSection(
            title: "Rehearse Route",
            icon: "waveform.path.ecg",
            body: """
            Runs a headless physics simulation over the entire route in the background. It does not move the vehicle on the map.

            Integrates vehicle physics at 100× speed, produces a kinetic physics ETA, and updates the shareable trip brief. Rehearse also runs automatically when a route loads (Refining physics ETA…).
            """
        )
    }

    private var playSection: some View {
        onboardingSection(
            title: "Play and speed multipliers",
            icon: "play.circle.fill",
            body: """
            Play runs live map playback: the oriented vehicle footprint moves along the route, the speed dial shows current speed and the legal limit, and lane guidance banners update near junctions.

            Speed multipliers (1×, 5×, 10×, 50×) affect playback speed only. They do not change stored ETAs or Rehearse results.
            """
        )
    }

    private var trafficSection: some View {
        onboardingSection(
            title: "Traffic delay banner",
            icon: "car.2.fill",
            body: """
            After route find, RouteFinder may sample TomTom traffic along the corridor. A banner appears when checking alternates or when congestion is detected and a faster alternate exists.

            Tap Recalculate to apply a traffic-aware alternate. Disable reroute evaluation in Settings → Navigation → Avoid traffic delays when routing.
            """
        )
    }

    private var laneSection: some View {
        onboardingSection(
            title: "Lane guidance",
            icon: "arrow.triangle.branch",
            body: """
            When OSM turn:lanes data is available, a banner shows which lane to use, for example Use lane 2. The strip shows lanes left-to-right with recommended lanes highlighted.

            Lane guidance appears after route find and during simulation or live navigation near the upcoming maneuver.
            """
        )
    }

    private var vehicleSection: some View {
        onboardingSection(
            title: "Vehicle on the map",
            icon: "truck.box.fill",
            body: """
            Your vehicle is drawn as a 2D oriented footprint, not a 3D model. Passenger cars use a single polygon; HGVs show cab and trailer when length ≥ 6 m.

            During simulation the green start pin is hidden so the footprint is not confused with the origin marker.
            """
        )
    }

    private var walkaroundSection: some View {
        onboardingSection(
            title: "DVSA walkaround",
            icon: "checklist",
            body: """
            Before driving, complete a local DVSA-style walkaround checklist. Open the map toolbar menu (⋯) → Walkaround check, or Settings → Walkaround inspection when HGV mode is enabled.

            Records are saved on device. Official defect books and fleet procedures remain authoritative.
            """
        )
    }

    private var breakNowSection: some View {
        onboardingSection(
            title: "Break Now",
            icon: "cup.and.saucer.fill",
            body: """
            The coffee-cup quick action finds the nearest suitable layby using HOS advisory, company break windows, physics ETA, and crowd occupancy taps.

            Toggle visibility in Settings → Navigation → Break Now quick action.
            """
        )
    }

    private var lezSection: some View {
        onboardingSection(
            title: "Low emission zones",
            icon: "leaf.fill",
            body: """
            UK LEZ and ULEZ crossings trigger restriction banners with Euro class guidance. Set your emission class in Settings → Vehicle and enable Avoid non-compliant LEZ when routing.
            """
        )
    }

    private var fleetSection: some View {
        onboardingSection(
            title: "Fleet dispatch (office LAN)",
            icon: "antenna.radiowaves.left.and.right",
            body: """
            Drivers: Settings → Fleet & Dispatch → Open fleet setup wizard — Discover the office Mac, Test connection, Scan the vehicle QR from Mac or web dispatch.

            Dispatchers: start RouteFinderFleetServer with --ors-key so routing is operator-paid; push trips from the Mac Dispatch window or the web console. No personal HeiGIT key needed on driver phones when the proxy is on.
            """
        )
    }

    private var searchLanguageSection: some View {
        onboardingSection(
            title: "Language",
            icon: "character.book.closed.fill",
            body: """
            Settings → Language controls Pelias search display language, optional English name fallback, and a separate map label language for basemap road and place names.

            Search results and pin labels use Pelias. Basemap labels update live when you change the map label picker.
            """
        )
    }

    private var quickReferenceSection: some View {
        VStack(alignment: .leading, spacing: RFSpacing.sm) {
            Text("Quick reference")
                .font(RFFont.sectionTitle)

            Grid(alignment: .leading, horizontalSpacing: RFSpacing.md, verticalSpacing: RFSpacing.xs) {
                GridRow {
                    Text("Control")
                        .font(RFFont.caption.weight(.semibold))
                    Text("Moves map?")
                        .font(RFFont.caption.weight(.semibold))
                    Text("Changes ETA?")
                        .font(RFFont.caption.weight(.semibold))
                }
                quickReferenceRow("Rehearse Route", movesMap: false, changesETA: true)
                quickReferenceRow("Play / speed", movesMap: true, changesETA: false)
                quickReferenceRow("Traffic Recalculate", movesMap: false, changesETA: true)
            }
        }
        .padding(RFSpacing.md)
        .glassPanel(cornerRadius: 14)
    }

    private var liabilitySection: some View {
        VStack(alignment: .leading, spacing: RFSpacing.sm) {
            Text("Driver Terms")
                .font(RFFont.sectionTitle)

            Text(Self.driverTermsBody)
                .font(RFFont.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Toggle(
                isOn: $liabilityAccepted,
                label: {
                    Text(Self.driverTermsAcceptanceLabel)
                        .font(RFFont.caption)
                        .fixedSize(horizontal: false, vertical: true)
                }
            )
            .accessibilityIdentifier("routingLiabilityToggle")
        }
        .padding(RFSpacing.md)
        .glassPanel(cornerRadius: 14)
    }

    /// Full Driver Terms copy shown on first launch and in Settings → Legal.
    /// Keep aligned with `Docs/legal/driver-terms.md` and Android `DRIVER_TERMS_BODY`.
    static let driverTermsBody = """
    Routing, physics rehearsal, layby suggestions, HOS advisories, and turn-by-turn guidance in RouteFinder are advisory planning aids only.

    Physical road signs, bridge height and weight plates, temporary restrictions, and immediate traffic conditions always supersede navigation instructions. Bridge strikes and constraint violations can trigger Traffic Commissioner action against operators and driver conduct hearings.

    You (and your operator, where applicable) remain solely responsible for safe, lawful driving and for verifying vehicle dimensions against the route before departure. The developer accepts no liability for incorrect routing, missed restrictions, or reliance on advisory outputs.
    """

    /// Checkbox label for mandatory first-launch acceptance.
    /// Keep aligned with `Docs/legal/driver-terms.md`.
    static let driverTermsAcceptanceLabel =
        "I understand routing and guidance are advisory only; physical signs and bridge plates always supersede the app; the developer is not liable for incorrect routing."

    private func onboardingSection(title: String, icon: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: RFSpacing.sm) {
            Label(title, systemImage: icon)
                .font(RFFont.sectionTitle)

            Text(body)
                .font(RFFont.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(RFSpacing.md)
        .glassPanel(cornerRadius: 14)
    }

    private func quickReferenceRow(_ control: String, movesMap: Bool, changesETA: Bool) -> some View {
        GridRow {
            Text(control)
                .font(RFFont.caption)
            Text(movesMap ? "Yes" : "No")
                .font(RFFont.caption)
            Text(changesETA ? "Yes" : "No")
                .font(RFFont.caption)
        }
    }

    private func markSeenAndDismiss() {
        if requireLiabilityAcceptance, liabilityAccepted {
            NavigationWorkspaceSettings.saveHasAcceptedRoutingLiability(true)
        }
        NavigationWorkspaceSettings.saveHasSeenProductOnboarding(true)
        if let onFinished {
            onFinished()
        } else {
            dismiss()
        }
    }
}
