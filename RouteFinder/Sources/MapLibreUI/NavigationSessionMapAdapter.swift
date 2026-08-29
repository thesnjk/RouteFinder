import Contracts
import CoreLocation
import Foundation
import NavigationCore
import RouteController

/// Forwards navigation session updates to the MapLibre map bridge.
@MainActor
public final class NavigationSessionMapAdapter: NavigationSessionDelegate {
    private let vehicleDimensionsProvider: () -> VehicleMapDimensions
    private let isPassengerCarProvider: () -> Bool

    /// Creates a map adapter that resolves vehicle dimensions for rendering.
    public init(
        vehicleDimensionsProvider: @escaping () -> VehicleMapDimensions,
        isPassengerCarProvider: @escaping () -> Bool = { false }
    ) {
        self.vehicleDimensionsProvider = vehicleDimensionsProvider
        self.isPassengerCarProvider = isPassengerCarProvider
    }

    /// Creates a map adapter with fixed vehicle dimensions.
    public init(lengthMeters: Double = 12, widthMeters: Double = 2.55, isPassengerCar: Bool = false) {
        self.vehicleDimensionsProvider = {
            VehicleMapDimensions(lengthMeters: lengthMeters, widthMeters: widthMeters)
        }
        self.isPassengerCarProvider = { isPassengerCar }
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
        let coordinate = CLLocationCoordinate2D(
            latitude: update.coordinate.latitude,
            longitude: update.coordinate.longitude
        )
        let bearing = update.bearingDegrees ?? 0
        let isPassengerCar = isPassengerCarProvider()
        let parts = VehicleGeometryCalculator.generateFootprintParts(
            rearAxle: coordinate,
            headingDegrees: bearing,
            lengthMeters: dimensions.lengthMeters,
            widthMeters: dimensions.widthMeters,
            isPassengerCar: isPassengerCar
        )
        let footprint = parts.first
            ?? VehicleGeometryCalculator.generateFootprint(
                rearAxle: coordinate,
                headingDegrees: bearing,
                lengthMeters: dimensions.lengthMeters,
                widthMeters: dimensions.widthMeters
            )
        let state = SimulatedVehicleState(
            latitude: update.coordinate.latitude,
            longitude: update.coordinate.longitude,
            bearing: bearing,
            visible: true,
            lengthMeters: dimensions.lengthMeters,
            widthMeters: dimensions.widthMeters,
            playbackRevision: 0,
            dimensionRevision: 0,
            renderMode: .polygon,
            footprintCoordinates: footprint,
            footprintParts: parts,
            isPassengerCar: isPassengerCar,
            wheelbaseMeters: isPassengerCar ? 2.7 : 6.5
        )
        NavigationMapBridge.shared.push(state)
    }

    public func navigationSession(_ session: NavigationSession, didUpdateRouteSplit split: RouteSplitResult) {
        NavigationMapBridge.shared.pushSplit(split)
    }
}
