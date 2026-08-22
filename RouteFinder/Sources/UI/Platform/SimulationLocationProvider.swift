import Contracts
import CoreLocation
import Foundation

/// Location provider that emits pose updates from route simulation playback.
@MainActor
public final class SimulationLocationProvider: LocationProvider {
    public let mode: LocationProviderMode = .simulation
    public private(set) var isActive = false
    public var accuracyThresholdMeters: Double = 0

    private weak var delegate: LocationProviderDelegate?
    private let poseSource: () -> (
        coordinate: CLLocationCoordinate2D,
        bearing: Double,
        speedKmh: Double,
        arcLengthMeters: Double?
    )?

    /// Creates a simulation location provider backed by a pose source closure.
    public init(
        poseSource: @escaping () -> (
            coordinate: CLLocationCoordinate2D,
            bearing: Double,
            speedKmh: Double,
            arcLengthMeters: Double?
        )? = { nil }
    ) {
        self.poseSource = poseSource
    }

    public func setDelegate(_ delegate: LocationProviderDelegate?) {
        self.delegate = delegate
    }

    public func start() async throws {
        isActive = true
    }

    public func stop() {
        isActive = false
    }

    /// Pushes the latest simulation pose as a navigation position update.
    public func emitCurrentPose() {
        guard isActive, let pose = poseSource() else { return }
        let update = NavigationPositionUpdate(
            coordinate: pose.coordinate,
            bearingDegrees: pose.bearing,
            speedMps: pose.speedKmh / 3.6,
            horizontalAccuracyMeters: 0,
            timestamp: Date(),
            source: .simulation,
            arcLengthMeters: pose.arcLengthMeters
        )
        delegate?.locationProvider(self, didReceive: update)
    }
}
