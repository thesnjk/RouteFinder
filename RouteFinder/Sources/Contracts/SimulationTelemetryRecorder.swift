import Foundation

/// Thread-safe ring buffer for simulation telemetry events.
public actor SimulationTelemetryRecorder {
    private var events: [SimulationEvent] = []
    private var simulationElapsedSeconds: TimeInterval = 0
    private var thermalFadeIntegral: Double = 0
    private var lateralGExcessSeconds: TimeInterval = 0
    private var peakBrakeFadeRisk: BrakeFadeRisk?

    /// Maximum events retained in memory.
    public static let maxEvents = 2000

    /// Creates an empty telemetry recorder.
    public init() {}

    /// Resets all recorded telemetry.
    public func reset() {
        events.removeAll()
        simulationElapsedSeconds = 0
        thermalFadeIntegral = 0
        lateralGExcessSeconds = 0
        peakBrakeFadeRisk = nil
    }

    /// Advances simulation elapsed time.
    public func advanceElapsedTime(_ deltaTime: TimeInterval) {
        simulationElapsedSeconds += deltaTime
    }

    /// Current simulation elapsed time in seconds.
    public func elapsedSeconds() -> TimeInterval {
        simulationElapsedSeconds
    }

    /// Records a simulation event.
    public func record(_ event: SimulationEvent) {
        events.append(event)
        if events.count > Self.maxEvents {
            events.removeFirst(events.count - Self.maxEvents)
        }

        switch event.kind {
        case .brakeFade:
            thermalFadeIntegral += event.magnitude
            if event.magnitude >= BrakeThermalThresholds.criticalLoadJoules {
                peakBrakeFadeRisk = .critical
            } else if peakBrakeFadeRisk != .critical {
                peakBrakeFadeRisk = .elevated
            }
        case .lateralGViolation:
            lateralGExcessSeconds += 0.033
        default:
            break
        }
    }

    /// All recorded events.
    public func allEvents() -> [SimulationEvent] {
        events
    }

    /// Aggregated counters for report generation.
    public func aggregatedCounters() -> (
        hardDecel: Int,
        brakeFade: Int,
        lateralG: Int,
        tireSlip: Int,
        thermalIntegral: Double,
        lateralGExcessSeconds: TimeInterval,
        peakBrakeFadeRisk: BrakeFadeRisk?
    ) {
        (
            hardDecel: events.filter { $0.kind == .hardDeceleration }.count,
            brakeFade: events.filter { $0.kind == .brakeFade }.count,
            lateralG: events.filter { $0.kind == .lateralGViolation }.count,
            tireSlip: events.filter { $0.kind == .tireSlip }.count,
            thermalIntegral: thermalFadeIntegral,
            lateralGExcessSeconds: lateralGExcessSeconds,
            peakBrakeFadeRisk: peakBrakeFadeRisk
        )
    }
}
