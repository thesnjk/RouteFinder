import Contracts
import CoreLocation
import Foundation

/// Headless navigation session coordinating route progress, position ingestion, and delegate fan-out.
@MainActor
@Observable
public final class NavigationSession {
    /// Current navigation lifecycle phase.
    public private(set) var phase: NavigationPhase = .idle
    /// Latest live progress snapshot, when navigating.
    public private(set) var progressSnapshot: NavigationProgressSnapshot?
    /// Latest position update.
    public private(set) var latestPosition: NavigationPositionUpdate?
    /// Latest route split result for map rendering.
    public private(set) var latestRouteSplit: RouteSplitResult?
    /// Active canonical route geometry.
    public private(set) var canonicalGeometry: RouteGeometryCanonicalizer.CanonicalRouteGeometry?
    /// Maneuver anchor catalog for distance-based guidance.
    public private(set) var maneuverAnchorCatalog: ManeuverAnchorCatalog?
    /// Static routing ETA in seconds from the routing engine.
    public private(set) var staticTotalTimeSeconds: Double = 0

    private let projector = RoutePolylineProjector()
    private let progressCalculator = RouteProgressCalculator()
    private var maneuverTracker: ManeuverProgressTracker?
    private var delegates: [WeakNavigationDelegate] = []
    private var lastManeuverIndex: Int?
    private var lastProgressFraction: Double = -1
    private var crossTrackThresholdMeters: Double = RoutePolylineProjector.defaultGPSThresholdMeters

    /// Creates a navigation session.
    public init() {}

    /// Registers a delegate to receive navigation updates.
    public func addDelegate(_ delegate: NavigationSessionDelegate) {
        guard !delegates.contains(where: { $0.value === delegate }) else { return }
        delegates.append(WeakNavigationDelegate(delegate))
        delegates.removeAll { $0.value == nil }
    }

    /// Removes a previously registered delegate.
    public func removeDelegate(_ delegate: NavigationSessionDelegate) {
        delegates.removeAll { $0.value === delegate || $0.value == nil }
    }

    /// Loads route geometry and turn instructions for subsequent navigation.
    public func loadRoute(
        canonical: RouteGeometryCanonicalizer.CanonicalRouteGeometry,
        turnInstructions: [TurnInstruction] = [],
        staticTotalTimeSeconds: Double = 0
    ) {
        canonicalGeometry = canonical
        self.staticTotalTimeSeconds = staticTotalTimeSeconds
        let catalog = ManeuverAnchorCatalogBuilder.build(
            instructions: turnInstructions,
            totalLengthMeters: canonical.totalLengthMeters
        )
        maneuverAnchorCatalog = catalog
        maneuverTracker = ManeuverProgressTracker(
            instructions: turnInstructions,
            cumulativeArcLengths: catalog.cumulativeArcLengths
        )
        lastManeuverIndex = nil
        lastProgressFraction = -1
        progressSnapshot = nil
        latestRouteSplit = nil
        setPhase(.routeLoaded)
    }

    /// Begins active navigation tracking.
    public func startNavigation(crossTrackThresholdMeters: Double = RoutePolylineProjector.defaultGPSThresholdMeters) {
        self.crossTrackThresholdMeters = crossTrackThresholdMeters
        setPhase(.navigating)
    }

    /// Stops navigation tracking and resets progress.
    public func stopNavigation() {
        progressSnapshot = nil
        latestRouteSplit = nil
        latestPosition = nil
        lastProgressFraction = -1
        setPhase(canonicalGeometry == nil ? .idle : .routeLoaded)
    }

    /// Clears all route state.
    public func clearRoute() {
        canonicalGeometry = nil
        maneuverAnchorCatalog = nil
        maneuverTracker = nil
        progressSnapshot = nil
        latestRouteSplit = nil
        latestPosition = nil
        staticTotalTimeSeconds = 0
        lastManeuverIndex = nil
        lastProgressFraction = -1
        setPhase(.idle)
    }

    /// Processes a position update from any location provider.
    public func ingestPositionUpdate(_ update: NavigationPositionUpdate) {
        latestPosition = update
        notifyDelegates { $0.navigationSession(self, didUpdatePosition: update) }

        guard phase == .navigating, let canonical = canonicalGeometry else { return }

        let threshold = update.source == .simulation
            ? RoutePolylineProjector.simulationThresholdMeters
            : crossTrackThresholdMeters

        let point = Coordinate(
            latitude: update.coordinate.latitude,
            longitude: update.coordinate.longitude
        )

        let arcLength: Double
        if let directArc = update.arcLengthMeters {
            arcLength = directArc
        } else if let projection = projector.project(
            point: point,
            spine: canonical,
            crossTrackThresholdMeters: threshold
        ) {
            arcLength = projection.arcLengthMeters
        } else {
            return
        }

        let maneuverIndex = maneuverTracker?.currentManeuverIndex(for: arcLength)
        let speedMps = update.speedMps
        let snapshot = progressCalculator.compute(
            arcLengthMeters: arcLength,
            totalLengthMeters: canonical.totalLengthMeters,
            currentSpeedMps: speedMps,
            staticTotalTimeSeconds: staticTotalTimeSeconds > 0 ? staticTotalTimeSeconds : nil,
            currentManeuverIndex: maneuverIndex
        )

        if abs(snapshot.progressFraction - lastProgressFraction) > 0.001 || lastProgressFraction < 0 {
            lastProgressFraction = snapshot.progressFraction
            progressSnapshot = snapshot
            notifyDelegates { $0.navigationSession(self, didUpdateProgress: snapshot) }

            let split = RouteGeometrySplitter.split(
                displayCoordinates: canonical.displayCoordinates,
                cumulativeLengths: displayCumulativeLengths(for: canonical),
                splitArcLengthMeters: arcLength
            )
            latestRouteSplit = split
            notifyDelegates { $0.navigationSession(self, didUpdateRouteSplit: split) }
        }

        if let maneuverIndex, maneuverIndex != lastManeuverIndex,
           let instruction = maneuverTracker?.currentManeuver(for: arcLength) {
            lastManeuverIndex = maneuverIndex
            notifyDelegates { $0.navigationSession(self, didAdvanceManeuver: instruction) }
        }

        if snapshot.progressFraction >= 1 {
            setPhase(.completed)
        }
    }

    /// Returns the current upcoming turn instruction for the given arc length, if any.
    public func currentInstruction(atArcLength arcLengthMeters: Double) -> TurnInstruction? {
        maneuverTracker?.currentManeuver(for: arcLengthMeters)
    }

    /// Returns the current upcoming turn instruction based on the latest progress snapshot.
    public func currentInstruction() -> TurnInstruction? {
        guard let snapshot = progressSnapshot else {
            return maneuverTracker?.currentManeuver(for: 0)
        }
        return maneuverTracker?.currentManeuver(for: snapshot.arcLengthMeters)
    }

    /// Reports an invalid vehicle profile lookup for alert presentation.
    public func reportInvalidVehicleProfile(_ message: String) {
        notifyDelegates { $0.navigationSession(self, didEncounterInvalidVehicleProfile: message) }
    }

    private func displayCumulativeLengths(
        for canonical: RouteGeometryCanonicalizer.CanonicalRouteGeometry
    ) -> [Double] {
        let displayCount = canonical.displayCoordinates.count
        let simCount = canonical.simulationCoordinates.count
        guard displayCount >= 2, simCount >= 2, canonical.totalLengthMeters > 0 else {
            return canonical.cumulativeLengths
        }

        if displayCount == simCount {
            return canonical.cumulativeLengths
        }

        var result: [Double] = [0]
        for index in 1..<displayCount {
            let fraction = Double(index) / Double(displayCount - 1)
            result.append(fraction * canonical.totalLengthMeters)
        }
        return result
    }

    private func setPhase(_ newPhase: NavigationPhase) {
        guard phase != newPhase else { return }
        phase = newPhase
        notifyDelegates { $0.navigationSession(self, didChangePhase: newPhase) }
    }

    private func notifyDelegates(_ action: (NavigationSessionDelegate) -> Void) {
        delegates.removeAll { $0.value == nil }
        for wrapper in delegates {
            if let delegate = wrapper.value {
                action(delegate)
            }
        }
    }
}

private final class WeakNavigationDelegate {
    weak var value: (any NavigationSessionDelegate)?

    init(_ value: any NavigationSessionDelegate) {
        self.value = value
    }
}
