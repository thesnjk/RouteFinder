import Contracts
import CoreLocation
import Foundation
import MapLibreUI
import NavigationCore

#if os(iOS)
import UIKit
#endif

/// Coordinates navigation session lifecycle, location providers, and delegate fan-out.
@MainActor
public final class NavigationCoordinator: LocationProviderDelegate {
    /// Headless navigation session hub.
    public let session = NavigationSession()
    /// Live metrics presentation model.
    public let metricsViewModel: NavigationMetricsViewModel
    /// Active location provider mode.
    public private(set) var activeMode: LocationProviderMode?
    /// Telemetry source registry for simulation/hardware hot-swapping.
    public let telemetryRegistry: TelemetrySourceRegistry

    private let mapAdapter: NavigationSessionMapAdapter
    private let metricsAdapter: NavigationMetricsSessionAdapter

    /// Creates a navigation coordinator with vehicle dimension resolution.
    public init(vehicleDimensionsProvider: @escaping () -> VehicleMapDimensions) {
        metricsViewModel = NavigationMetricsViewModel(session: session)
        mapAdapter = NavigationSessionMapAdapter(vehicleDimensionsProvider: vehicleDimensionsProvider)
        metricsAdapter = NavigationMetricsSessionAdapter(metricsViewModel: metricsViewModel)
        telemetryRegistry = TelemetrySourceRegistry()

        session.addDelegate(mapAdapter)
        session.addDelegate(metricsAdapter)
        telemetryRegistry.locationProvider.setDelegate(self)
    }

    /// Configures the simulation pose source from the simulation engine.
    public func configureSimulationPoseSource(
        _ source: @escaping () -> (
            coordinate: CLLocationCoordinate2D,
            bearing: Double,
            speedKmh: Double,
            arcLengthMeters: Double?
        )?
    ) {
        telemetryRegistry.configureSimulationPoseSource {
            guard let pose = source() else { return nil }
            return (
                coordinate: pose.coordinate,
                bearing: pose.bearing,
                speedKmh: pose.speedKmh,
                arcLengthMeters: pose.arcLengthMeters,
                altitudeMeters: nil
            )
        }
    }

    /// Loads route geometry into the navigation session and map bridge.
    public func loadRoute(
        canonical: RouteGeometryCanonicalizer.CanonicalRouteGeometry,
        turnInstructions: [TurnInstruction] = [],
        staticTotalTimeSeconds: Double = 0
    ) {
        session.loadRoute(
            canonical: canonical,
            turnInstructions: turnInstructions,
            staticTotalTimeSeconds: staticTotalTimeSeconds
        )
        NavigationMapBridge.shared.loadRoute(
            coordinates: canonical.displayCoordinates,
            cumulativeLengths: displayCumulativeLengths(for: canonical),
            totalLengthMeters: canonical.totalLengthMeters
        )
        NavigationMapBridge.shared.revealRoute(
            coordinates: canonical.displayCoordinates,
            totalLengthMeters: canonical.totalLengthMeters,
            cumulativeLengths: displayCumulativeLengths(for: canonical)
        )
    }

    /// Starts simulation-based navigation tracking.
    public func startSimulationNavigation() async throws {
        try await telemetryRegistry.switchMode(to: .simulation)
        try await telemetryRegistry.locationProvider.start()
        session.startNavigation(crossTrackThresholdMeters: RoutePolylineProjector.simulationThresholdMeters)
        activeMode = .simulation
    }

    #if os(iOS)
    /// Starts hardware GPS navigation tracking.
    public func startGPSNavigation(enableHeading: Bool = false) async throws {
        if enableHeading {
            telemetryRegistry.enableHardwareHeading(true)
        }
        try await telemetryRegistry.switchMode(to: .hardwareGPS)
        try await telemetryRegistry.locationProvider.start()
        session.startNavigation()
        activeMode = .hardwareGPS
    }
    #endif

    /// Stops active navigation tracking.
    public func stopNavigation() {
        telemetryRegistry.locationProvider.stop()
        activeMode = nil
        session.stopNavigation()
        #if os(iOS)
        telemetryRegistry.enableHardwareHeading(false)
        #endif
    }

    /// Clears route and navigation state.
    public func clearRoute() {
        stopNavigation()
        session.clearRoute()
    }

    /// Emits the current simulation pose through the navigation pipeline.
    public func emitSimulationPose() {
        telemetryRegistry.emitSimulationSample()
    }

    /// Reports invalid vehicle profile for alert workflows.
    public func reportInvalidVehicleProfile(_ message: String) {
        session.reportInvalidVehicleProfile(message)
    }

    // MARK: - LocationProviderDelegate

    public func locationProvider(_ provider: any LocationProvider, didReceive update: NavigationPositionUpdate) {
        session.ingestPositionUpdate(update)
    }

    #if os(iOS)
    public func locationProvider(_ provider: any LocationProvider, didChangeAuthorization status: CLAuthorizationStatus) {}
    #endif

    public func locationProvider(_ provider: any LocationProvider, didFailWithError error: Error) {}

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
}
