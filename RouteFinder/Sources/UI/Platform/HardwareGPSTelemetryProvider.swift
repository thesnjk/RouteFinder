#if os(iOS)
import Contracts
import CoreLocation
import CoreMotion
import Foundation

/// Telemetry provider powered by CoreLocation with motion fusion fallback.
@MainActor
public final class HardwareGPSTelemetryProvider: NSObject, TelemetryStreamProvider, @preconcurrency CLLocationManagerDelegate {
    public let sourceMode: LocationProviderMode = .hardwareGPS
    public private(set) var isActive = false
    public private(set) var latestQuality: TelemetryQualityIndicator = .live
    public var accuracyThresholdMeters: Double = 25

    private weak var delegate: TelemetryStreamDelegate?
    private let manager = CLLocationManager()
    private let motionManager = CMMotionManager()
    private let altimeter = CMAltimeter()
    private let fusion = MotionFusionActor()
    private var isUpdatingHeading = false
    private var lastHeading: CLHeading?
    private var revision: UInt64 = 0
    private var fusionTimer: Timer?
    private var lastBarometricRelative: Double?

    public override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        manager.activityType = .automotiveNavigation
        manager.distanceFilter = 5
        manager.pausesLocationUpdatesAutomatically = false
    }

    public func setDelegate(_ delegate: TelemetryStreamDelegate?) {
        self.delegate = delegate
    }

    public func start() async throws {
        guard !isActive else { return }
        isActive = true
        requestAuthorizationForNavigation()
        configureBackgroundUpdatesIfAuthorized()
        manager.startUpdatingLocation()
        startMotionSensors()
        startFusionTimer()
    }

    public func stop() {
        isActive = false
        manager.allowsBackgroundLocationUpdates = false
        manager.showsBackgroundLocationIndicator = false
        manager.stopUpdatingLocation()
        stopHeadingUpdatesIfNeeded()
        stopMotionSensors()
        fusionTimer?.invalidate()
        fusionTimer = nil
        Task { await fusion.reset() }
    }

    /// Requests Always authorization and enables background GPS for active navigation.
    public func enableBackgroundNavigation() {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse:
            manager.requestAlwaysAuthorization()
        case .authorizedAlways:
            break
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        default:
            break
        }
        configureBackgroundUpdatesIfAuthorized()
    }

    private func requestAuthorizationForNavigation() {
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse:
            manager.requestAlwaysAuthorization()
        default:
            break
        }
    }

    private func configureBackgroundUpdatesIfAuthorized() {
        let status = manager.authorizationStatus
        let authorized = status == .authorizedAlways || status == .authorizedWhenInUse
        guard authorized else { return }
        manager.allowsBackgroundLocationUpdates = true
        manager.showsBackgroundLocationIndicator = true
    }

    /// Enables compass heading updates for low-speed bearing fallback.
    public func startHeadingUpdatesIfNeeded() {
        guard !isUpdatingHeading else { return }
        isUpdatingHeading = true
        manager.startUpdatingHeading()
    }

    /// Disables compass heading updates.
    public func stopHeadingUpdatesIfNeeded() {
        guard isUpdatingHeading else { return }
        isUpdatingHeading = false
        manager.stopUpdatingHeading()
        lastHeading = nil
    }

    public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard isActive, let location = locations.last else { return }
        guard location.horizontalAccuracy >= 0,
              location.horizontalAccuracy <= accuracyThresholdMeters else { return }

        let speed = location.speed >= 0 ? location.speed : nil
        let course = location.course >= 0 ? location.course : nil
        let bearing = resolvedBearing(speed: speed, course: course)
        let altitude = location.verticalAccuracy >= 0 ? location.altitude : nil

        Task {
            await fusion.ingestGPS(
                coordinate: location.coordinate,
                course: bearing,
                speedMps: speed,
                altitude: altitude,
                timestamp: location.timestamp
            )
        }

        emitSample(
            coordinate: location.coordinate,
            course: bearing,
            speedMps: speed,
            altitudeMeters: altitude,
            horizontalAccuracy: location.horizontalAccuracy,
            timestamp: location.timestamp,
            quality: .live
        )
    }

    public func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        lastHeading = newHeading
    }

    public func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        if isActive,
           manager.authorizationStatus == .authorizedWhenInUse
               || manager.authorizationStatus == .authorizedAlways {
            configureBackgroundUpdatesIfAuthorized()
            manager.startUpdatingLocation()
        }
    }

    public func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {}

    private func startMotionSensors() {
        guard motionManager.isAccelerometerAvailable else { return }
        motionManager.accelerometerUpdateInterval = 0.05
        motionManager.startAccelerometerUpdates(to: .main) { [weak self] data, _ in
            guard let self, let data else { return }
            let longitudinal = data.acceleration.y
            Task { await self.fusion.ingestAccelerometer(longitudinalAcceleration: longitudinal) }
        }

        guard CMAltimeter.isRelativeAltitudeAvailable() else { return }
        altimeter.startRelativeAltitudeUpdates(to: .main) { [weak self] data, _ in
            guard let self, let data else { return }
            if let previous = self.lastBarometricRelative {
                let delta = data.relativeAltitude.doubleValue - previous
                Task { await self.fusion.ingestBarometric(relativeAltitudeMeters: delta) }
            }
            self.lastBarometricRelative = data.relativeAltitude.doubleValue
        }
    }

    private func stopMotionSensors() {
        motionManager.stopAccelerometerUpdates()
        altimeter.stopRelativeAltitudeUpdates()
        lastBarometricRelative = nil
    }

    private func startFusionTimer() {
        fusionTimer?.invalidate()
        fusionTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.evaluateDeadReckoning() }
        }
    }

    private func evaluateDeadReckoning() {
        guard isActive else { return }
        Task {
            guard let fused = await fusion.extrapolatedSample(at: Date()) else { return }
            emitSample(
                coordinate: fused.coordinate,
                course: fused.course,
                speedMps: fused.speedMps,
                altitudeMeters: fused.altitude,
                horizontalAccuracy: accuracyThresholdMeters,
                timestamp: Date(),
                quality: fused.quality
            )
        }
    }

    private func emitSample(
        coordinate: CLLocationCoordinate2D,
        course: Double?,
        speedMps: Double?,
        altitudeMeters: Double?,
        horizontalAccuracy: Double,
        timestamp: Date,
        quality: TelemetryQualityIndicator
    ) {
        latestQuality = quality
        revision &+= 1
        let sample = TelemetryStreamSample(
            coordinate: coordinate,
            courseDegrees: course,
            speedMps: speedMps,
            altitudeMeters: altitudeMeters,
            horizontalAccuracyMeters: horizontalAccuracy,
            timestamp: timestamp,
            sourceMode: .hardwareGPS,
            arcLengthMeters: nil,
            qualityIndicator: quality,
            revision: revision
        )
        delegate?.telemetryStreamProvider(self, didEmit: sample)
    }

    private func resolvedBearing(speed: Double?, course: Double?) -> Double? {
        if let speed, speed >= 1, let course {
            return course
        }
        if let heading = lastHeading?.trueHeading, heading >= 0 {
            return heading
        }
        if let heading = lastHeading?.magneticHeading, heading >= 0 {
            return heading
        }
        return course
    }
}
#endif
