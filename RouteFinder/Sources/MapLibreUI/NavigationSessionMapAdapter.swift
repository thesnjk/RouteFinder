import Contracts
import CoreLocation
import Foundation
import NavigationCore

/// Forwards navigation session updates to the MapLibre map bridge.
@MainActor
public final class NavigationSessionMapAdapter: NavigationSessionDelegate {
    private let vehicleDimensionsProvider: () -> VehicleMapDimensions

    /// Creates a map adapter that resolves vehicle dimensions for rendering.
    public init(vehicleDimensionsProvider: @escaping () -> VehicleMapDimensions) {
        self.vehicleDimensionsProvider = vehicleDimensionsProvider
    }

    /// Creates a map adapter with fixed vehicle dimensions.
    public init(lengthMeters: Double = 12, widthMeters: Double = 2.55) {
        self.vehicleDimensionsProvider = {
            VehicleMapDimensions(lengthMeters: lengthMeters, widthMeters: widthMeters)
        }
    }

    public func navigationSession(_ session: NavigationSession, didUpdateProgress snapshot: NavigationProgressSnapshot) {
        NavigationMapBridge.shared.pushProgress(
            RouteProgressState.from(
                arcLengthMeters: snapshot.arcLengthMeters,
                totalLengthMeters: snapshot.totalLengthMeters,
                phase: .tracking
            )
        )
    }

    public func navigationSession(_ session: NavigationSession, didUpdatePosition update: NavigationPositionUpdate) {
        let dimensions = vehicleDimensionsProvider()
        let state = SimulatedVehicleState(
            latitude: update.coordinate.latitude,
            longitude: update.coordinate.longitude,
            bearing: update.bearingDegrees ?? 0,
            visible: true,
            lengthMeters: dimensions.lengthMeters,
            widthMeters: dimensions.widthMeters,
            playbackRevision: 0,
            dimensionRevision: 0,
            renderMode: .polygon,
            footprintCoordinates: []
        )
        NavigationMapBridge.shared.push(state)
    }

    public func navigationSession(_ session: NavigationSession, didUpdateRouteSplit split: RouteSplitResult) {
        NavigationMapBridge.shared.pushSplit(split)
    }
}
