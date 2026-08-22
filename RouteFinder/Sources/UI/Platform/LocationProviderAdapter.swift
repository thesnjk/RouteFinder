import Contracts
import CoreLocation
import Foundation

/// Bridges an active telemetry stream provider to the existing location provider protocol.
@MainActor
public final class LocationProviderAdapter: LocationProvider, TelemetryStreamDelegate {
    public var mode: LocationProviderMode { telemetryProvider?.sourceMode ?? .simulation }
    public private(set) var isActive = false
    public var accuracyThresholdMeters: Double {
        get { telemetryProvider?.accuracyThresholdMeters ?? 25 }
        set { telemetryProvider?.accuracyThresholdMeters = newValue }
    }

    private weak var delegate: LocationProviderDelegate?
    private var telemetryProvider: (any TelemetryStreamProvider)?
    private var simulationEmitHandler: (() -> Void)?

    public init() {}

    /// Binds this adapter to a telemetry stream provider.
    public func bind(to provider: any TelemetryStreamProvider) {
        telemetryProvider?.setDelegate(nil)
        telemetryProvider = provider
        provider.setDelegate(self)
    }

    /// Registers a handler invoked for pull-based simulation pose emission.
    public func setSimulationEmitHandler(_ handler: @escaping () -> Void) {
        simulationEmitHandler = handler
    }

    public func setDelegate(_ delegate: LocationProviderDelegate?) {
        self.delegate = delegate
    }

    public func start() async throws {
        guard let telemetryProvider else { return }
        isActive = true
        try await telemetryProvider.start()
    }

    public func stop() {
        isActive = false
        telemetryProvider?.stop()
    }

    /// Emits the latest simulation pose when using pull-based simulation playback.
    public func emitCurrentPose() {
        simulationEmitHandler?()
    }

    public func telemetryStreamProvider(
        _ provider: any TelemetryStreamProvider,
        didEmit sample: TelemetryStreamSample
    ) {
        guard isActive else { return }
        delegate?.locationProvider(self, didReceive: sample.navigationPositionUpdate)
    }
}
