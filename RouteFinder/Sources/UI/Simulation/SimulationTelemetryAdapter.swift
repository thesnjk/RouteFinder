import Contracts
import CoreLocation
import Foundation

/// Emits telemetry samples from route simulation playback.
@MainActor
public final class SimulationTelemetryAdapter: TelemetryStreamProvider {
    public let sourceMode: LocationProviderMode = .simulation
    public private(set) var isActive = false
    public private(set) var latestQuality: TelemetryQualityIndicator = .live
    public var accuracyThresholdMeters: Double = 0

    private weak var delegate: TelemetryStreamDelegate?
    private var revision: UInt64 = 0
    private let poseSource: () -> (
        coordinate: CLLocationCoordinate2D,
        bearing: Double,
        speedKmh: Double,
        arcLengthMeters: Double?,
        altitudeMeters: Double?
    )?

    /// Creates a simulation telemetry adapter backed by a pose source closure.
    public init(
        poseSource: @escaping () -> (
            coordinate: CLLocationCoordinate2D,
            bearing: Double,
            speedKmh: Double,
            arcLengthMeters: Double?,
            altitudeMeters: Double?
        )? = { nil }
    ) {
        self.poseSource = poseSource
    }

    public func setDelegate(_ delegate: TelemetryStreamDelegate?) {
        self.delegate = delegate
    }

    public func start() async throws {
        isActive = true
    }

    public func stop() {
        isActive = false
    }

    /// Pushes the latest simulation pose as a telemetry sample.
    public func emitCurrentSample() {
        guard isActive, let pose = poseSource() else { return }
        revision &+= 1
        let sample = TelemetryStreamSample(
            coordinate: pose.coordinate,
            courseDegrees: pose.bearing,
            speedMps: pose.speedKmh / 3.6,
            altitudeMeters: pose.altitudeMeters,
            horizontalAccuracyMeters: 0,
            timestamp: Date(),
            sourceMode: .simulation,
            arcLengthMeters: pose.arcLengthMeters,
            qualityIndicator: .live,
            revision: revision
        )
        delegate?.telemetryStreamProvider(self, didEmit: sample)
    }
}
