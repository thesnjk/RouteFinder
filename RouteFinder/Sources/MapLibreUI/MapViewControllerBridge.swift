import Combine
import Contracts
import CoreLocation
import Foundation
import RouteController

/// Vehicle footprint dimensions for map rendering.
public struct VehicleMapDimensions: Sendable, Equatable {
    /// Length in meters.
    public let lengthMeters: Double
    /// Width in meters.
    public let widthMeters: Double

    /// Creates vehicle map dimensions.
    public init(lengthMeters: Double, widthMeters: Double) {
        self.lengthMeters = lengthMeters
        self.widthMeters = widthMeters
    }
}

/// Level-of-detail rendering mode for the simulated vehicle on the map.
public enum VehicleRenderMode: String, Sendable, Equatable {
    /// True-to-scale oriented rectangle polygon.
    case polygon
    /// Fixed-size circular icon for macro zoom levels.
    case icon
}

/// Coordinates map camera tracking and vehicle level-of-detail rendering.
@MainActor
public final class MapViewControllerBridge: ObservableObject {
    /// Zoom level at which true-to-size polygon rendering begins.
    public static let lodZoomThreshold: Double = 16.0

    /// When true, the map camera follows the vehicle (derived from camera mode).
    @Published public var isTrackingVehicle: Bool = true
    /// Active camera tracking mode.
    @Published public var cameraMode: CameraTrackingMode = .lockNorth
    /// Target zoom when tracking the vehicle.
    @Published public var trackingZoomLevel: Double = 16.5
    /// Latest reported map zoom from the web canvas.
    @Published public var currentMapZoom: Double = 12.0

    /// Active vehicle specification profile for map footprint dimensions.
    public var activeSpecificationProfile: VehicleSpecificationProfile?

    /// Camera tracking state machine.
    public let cameraStateMachine = CameraTrackingStateMachine()

    /// Minimum zoom delta before a tracking move includes an explicit zoom level.
    private static let trackingZoomEpsilon = 0.05

    /// Minimum interval between camera tracking updates (~30 Hz).
    private static let cameraUpdateIntervalSeconds = 1.0 / 30.0
    /// Camera ease duration matched to the tracking update interval.
    private static let cameraEaseDurationMs = 33

    /// Handler invoked to animate the map center (lng, lat, optional zoom, durationMs).
    public var easeToCenterHandler: ((Double, Double, Double?, Int) -> Void)?
    /// Handler invoked for navigation camera moves with bearing and pitch.
    public var easeToNavigationHandler: ((MapCameraCommand) -> Void)?
    /// Handler invoked to fit the cached route bounds with edge padding.
    public var fitRouteBoundsHandler: ((MapEdgePadding) -> Void)?
    /// Handler invoked to zoom the map by a delta level.
    public var zoomByHandler: ((Double) -> Void)?

    private var lastCameraUpdateInstant: ContinuousClock.Instant?

    /// Creates a map view controller bridge.
    public init() {}

    /// Returns the vehicle render mode for a given map zoom level.
    public func renderMode(for zoom: Double) -> VehicleRenderMode {
        zoom >= Self.lodZoomThreshold ? .polygon : .icon
    }

    /// Computes the georeferenced vehicle footprint ring for the map simulation layer.
    public func updateVehicleSimulationLayer(
        currentLocation: CLLocationCoordinate2D,
        headingDegrees: Double,
        activeProfile: VehicleSpecificationProfile?,
        lengthMeters: Double,
        widthMeters: Double
    ) -> [CLLocationCoordinate2D] {
        let resolvedLength = activeProfile?.lengthMeters ?? lengthMeters
        let resolvedWidth = activeProfile?.widthMeters ?? widthMeters
        return VehicleGeometryCalculator.generateFootprint(
            rearAxle: currentLocation,
            headingDegrees: headingDegrees,
            lengthMeters: resolvedLength,
            widthMeters: resolvedWidth
        )
    }

    /// Resolves Ackermann wheelbase distance from an active profile or passenger/HGV fallback.
    public static func resolvedWheelbaseMeters(
        activeProfile: VehicleSpecificationProfile?,
        isPassengerCar: Bool
    ) -> Double {
        if let activeProfile {
            return activeProfile.wheelbaseMeters
        }
        return isPassengerCar ? 2.7 : 6.5
    }

    /// Sets the camera tracking mode and syncs tracking state.
    public func setCameraMode(_ mode: CameraTrackingMode) {
        cameraMode = mode
        cameraStateMachine.transition(to: mode)
        isTrackingVehicle = mode != .freePan
    }

    /// Notifies the bridge of a vehicle position update during navigation.
    public func vehicleDidUpdate(
        coordinate: CLLocationCoordinate2D,
        bearing: Double,
        dimensions: VehicleMapDimensions
    ) {
        guard isTrackingVehicle, cameraMode != .freePan else { return }

        let now = ContinuousClock.now
        if let lastCameraUpdateInstant {
            let elapsed = Self.seconds(from: lastCameraUpdateInstant.duration(to: now))
            if elapsed < Self.cameraUpdateIntervalSeconds {
                return
            }
        }
        lastCameraUpdateInstant = now

        let zoom: Double?
        if abs(currentMapZoom - trackingZoomLevel) > Self.trackingZoomEpsilon {
            zoom = trackingZoomLevel
        } else {
            zoom = nil
        }

        let mapBearing = cameraStateMachine.mapBearing(forVehicleBearing: bearing)
        let mapPitch = cameraStateMachine.mapPitch()

        if mapBearing != nil || mapPitch != nil {
            let command = MapCameraCommand(
                longitude: coordinate.longitude,
                latitude: coordinate.latitude,
                zoom: zoom,
                bearing: mapBearing,
                pitch: mapPitch,
                durationMs: Self.cameraEaseDurationMs
            )
            if let easeToNavigationHandler {
                easeToNavigationHandler(command)
            } else {
                easeToCenterHandler?(
                    coordinate.longitude,
                    coordinate.latitude,
                    zoom,
                    Self.cameraEaseDurationMs
                )
            }
        } else {
            easeToCenterHandler?(
                coordinate.longitude,
                coordinate.latitude,
                zoom,
                Self.cameraEaseDurationMs
            )
        }
    }

    private static func seconds(from duration: Duration) -> Double {
        let components = duration.components
        return Double(components.seconds)
            + Double(components.attoseconds) / 1_000_000_000_000_000_000
    }

    /// Notifies the bridge that the map viewport moved.
    public func mapDidMove(
        center: CLLocationCoordinate2D,
        zoom: Double,
        userInitiated: Bool
    ) {
        currentMapZoom = zoom
        if userInitiated {
            isTrackingVehicle = false
            cameraMode = .freePan
            cameraStateMachine.userDidPanOrZoom()
        }
    }

    /// Re-enables vehicle tracking and flies to the given coordinate.
    public func resumeTracking(at coordinate: CLLocationCoordinate2D, mode: CameraTrackingMode = .lockNorth) {
        setCameraMode(mode)
        let mapBearing = cameraStateMachine.mapBearing(forVehicleBearing: 0) ?? 0
        let mapPitch = cameraStateMachine.mapPitch() ?? 0
        let command = MapCameraCommand(
            longitude: coordinate.longitude,
            latitude: coordinate.latitude,
            zoom: trackingZoomLevel,
            bearing: mode == .lockHeading ? mapBearing : 0,
            pitch: mode == .lockHeading ? mapPitch : 0,
            durationMs: 400
        )
        if let easeToNavigationHandler {
            easeToNavigationHandler(command)
        } else {
            easeToCenterHandler?(
                coordinate.longitude,
                coordinate.latitude,
                trackingZoomLevel,
                400
            )
        }
    }

    /// Fits the visible map viewport to the loaded route polyline.
    public func fitRouteToBounds(padding: MapEdgePadding = .defaultRouteFit) {
        fitRouteBoundsHandler?(padding)
    }

    /// Zooms the map by the given delta level.
    public func zoomBy(_ delta: Double) {
        zoomByHandler?(delta)
    }
}
