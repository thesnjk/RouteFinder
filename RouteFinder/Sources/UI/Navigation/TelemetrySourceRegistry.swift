import Contracts
import CoreLocation
import Foundation

/// Central registry for hot-swapping simulation and hardware telemetry pipelines.
@MainActor
public final class TelemetrySourceRegistry {
    public private(set) var activeMode: LocationProviderMode
    public private(set) var activeProvider: any TelemetryStreamProvider

    private var simulationAdapter: SimulationTelemetryAdapter
    #if os(iOS)
    private let hardwareAdapter: HardwareGPSTelemetryProvider
    #endif
    private let locationAdapter: LocationProviderAdapter

    /// Creates a telemetry source registry with persisted or default mode.
    public init() {
        let preferred = NavigationWorkspaceSettings.loadTelemetrySourceMode()
        simulationAdapter = SimulationTelemetryAdapter()
        #if os(iOS)
        hardwareAdapter = HardwareGPSTelemetryProvider()
        #endif
        locationAdapter = LocationProviderAdapter()

        #if os(iOS)
        if preferred == .hardwareGPS {
            activeMode = .hardwareGPS
            activeProvider = hardwareAdapter
        } else {
            activeMode = .simulation
            activeProvider = simulationAdapter
        }
        #else
        activeMode = .simulation
        activeProvider = simulationAdapter
        #endif

        locationAdapter.bind(to: activeProvider)
        locationAdapter.setSimulationEmitHandler { [weak self] in
            self?.simulationAdapter.emitCurrentSample()
        }
    }

    /// Location provider adapter consumed by navigation coordinator.
    public var locationProvider: LocationProviderAdapter { locationAdapter }

    /// Latest telemetry quality from the active provider.
    public var latestQuality: TelemetryQualityIndicator {
        activeProvider.latestQuality
    }

    /// Configures the simulation pose source from the simulation engine.
    public func configureSimulationPoseSource(
        _ source: @escaping () -> (
            coordinate: CLLocationCoordinate2D,
            bearing: Double,
            speedKmh: Double,
            arcLengthMeters: Double?,
            altitudeMeters: Double?
        )?
    ) {
        let wasActive = simulationAdapter.isActive
        simulationAdapter.stop()
        simulationAdapter = SimulationTelemetryAdapter(poseSource: source)
        if activeMode == .simulation {
            activeProvider = simulationAdapter
            locationAdapter.bind(to: simulationAdapter)
            if wasActive {
                Task { try? await simulationAdapter.start() }
            }
        }
    }

    /// Switches the active telemetry pipeline.
    public func switchMode(to mode: LocationProviderMode) async throws {
        guard mode != activeMode || !activeProvider.isActive else { return }

        activeProvider.stop()
        switch mode {
        case .simulation:
            activeProvider = simulationAdapter
            activeMode = .simulation
        #if os(iOS)
        case .hardwareGPS:
            activeProvider = hardwareAdapter
            activeMode = .hardwareGPS
        #else
        case .hardwareGPS:
            throw TelemetrySourceRegistryError.hardwareGPSUnavailable
        #endif
        }

        locationAdapter.bind(to: activeProvider)
        NavigationWorkspaceSettings.saveTelemetrySourceMode(mode)
        try await activeProvider.start()
    }

    #if os(iOS)
    /// Enables compass heading on the hardware provider when needed.
    public func enableHardwareHeading(_ enabled: Bool) {
        if enabled {
            hardwareAdapter.startHeadingUpdatesIfNeeded()
        } else {
            hardwareAdapter.stopHeadingUpdatesIfNeeded()
        }
    }
    #endif

    /// Emits the current simulation sample through the navigation pipeline.
    public func emitSimulationSample() {
        simulationAdapter.emitCurrentSample()
    }
}

/// Errors when switching telemetry sources.
public enum TelemetrySourceRegistryError: Error, Sendable, LocalizedError {
    case hardwareGPSUnavailable

    public var errorDescription: String? {
        switch self {
        case .hardwareGPSUnavailable:
            "Hardware GPS is only available on iOS."
        }
    }
}
