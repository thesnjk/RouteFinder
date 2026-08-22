import Foundation

/// Receives merged telemetry samples from a stream provider.
@MainActor
public protocol TelemetryStreamDelegate: AnyObject {
    /// Called when a new merged telemetry sample is available.
    func telemetryStreamProvider(
        _ provider: any TelemetryStreamProvider,
        didEmit sample: TelemetryStreamSample
    )
}

/// Abstracts position ingestion from simulation or hardware sensors.
@MainActor
public protocol TelemetryStreamProvider: AnyObject {
    /// Active operational mode.
    var sourceMode: LocationProviderMode { get }
    /// Whether the provider is actively emitting updates.
    var isActive: Bool { get }
    /// Latest quality indicator from the most recent sample.
    var latestQuality: TelemetryQualityIndicator { get }
    /// Maximum horizontal accuracy to accept GPS samples.
    var accuracyThresholdMeters: Double { get set }

    /// Starts emitting telemetry updates.
    func start() async throws
    /// Stops emitting telemetry updates.
    func stop()
    /// Sets the delegate for merged sample callbacks.
    func setDelegate(_ delegate: TelemetryStreamDelegate?)
}
