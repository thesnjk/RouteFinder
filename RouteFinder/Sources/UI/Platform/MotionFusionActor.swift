#if os(iOS)
import Contracts
import CoreLocation
import CoreMotion
import Foundation

/// Actor-isolated dead-reckoning state for brief GPS dropouts.
public actor MotionFusionActor {
    private var lastCoordinate: CLLocationCoordinate2D?
    private var lastCourse: Double?
    private var lastSpeedMps: Double?
    private var lastAltitude: Double?
    private var lastGPSTimestamp: Date?
    private var deadReckoningStartedAt: Date?
    private var lastLongitudinalAcceleration: Double = 0

    private let gpsStaleThresholdSeconds: TimeInterval = 2
    private let deadReckoningMaxSeconds: TimeInterval = 30

    public init() {}

    /// Updates motion sensor readings for speed correction.
    public func ingestAccelerometer(longitudinalAcceleration: Double) {
        lastLongitudinalAcceleration = longitudinalAcceleration
    }

    /// Updates barometric relative altitude delta.
    public func ingestBarometric(relativeAltitudeMeters: Double) {
        if let lastAltitude {
            self.lastAltitude = lastAltitude + relativeAltitudeMeters
        }
    }

    /// Records a fresh GPS fix.
    public func ingestGPS(
        coordinate: CLLocationCoordinate2D,
        course: Double?,
        speedMps: Double?,
        altitude: Double?,
        timestamp: Date
    ) {
        lastCoordinate = coordinate
        lastCourse = course
        lastSpeedMps = speedMps
        if let altitude { lastAltitude = altitude }
        lastGPSTimestamp = timestamp
        deadReckoningStartedAt = nil
    }

    /// Returns a fused sample when GPS is stale, or nil when live GPS should be used.
    public func extrapolatedSample(at now: Date) -> (
        coordinate: CLLocationCoordinate2D,
        course: Double?,
        speedMps: Double?,
        altitude: Double?,
        quality: TelemetryQualityIndicator
    )? {
        guard let lastCoordinate,
              let lastGPSTimestamp,
              now.timeIntervalSince(lastGPSTimestamp) > gpsStaleThresholdSeconds else {
            return nil
        }

        if deadReckoningStartedAt == nil {
            deadReckoningStartedAt = now
        }

        guard let started = deadReckoningStartedAt else { return nil }
        let elapsed = now.timeIntervalSince(started)

        if elapsed > deadReckoningMaxSeconds {
            return (
                coordinate: lastCoordinate,
                course: lastCourse,
                speedMps: 0,
                altitude: lastAltitude,
                quality: .stale
            )
        }

        let speed = max(0, min(55, (lastSpeedMps ?? 0) + lastLongitudinalAcceleration * 0.1))
        let course = lastCourse ?? 0
        let distance = speed * elapsed
        let coordinate = propagate(coordinate: lastCoordinate, courseDegrees: course, distanceMeters: distance)

        return (
            coordinate: coordinate,
            course: lastCourse,
            speedMps: speed,
            altitude: lastAltitude,
            quality: .deadReckoning
        )
    }

    public func reset() {
        lastCoordinate = nil
        lastCourse = nil
        lastSpeedMps = nil
        lastAltitude = nil
        lastGPSTimestamp = nil
        deadReckoningStartedAt = nil
        lastLongitudinalAcceleration = 0
    }

    private func propagate(
        coordinate: CLLocationCoordinate2D,
        courseDegrees: Double,
        distanceMeters: Double
    ) -> CLLocationCoordinate2D {
        let earthRadius = 6_371_000.0
        let bearing = courseDegrees * .pi / 180
        let lat1 = coordinate.latitude * .pi / 180
        let lon1 = coordinate.longitude * .pi / 180
        let angularDistance = distanceMeters / earthRadius

        let lat2 = asin(
            sin(lat1) * cos(angularDistance)
                + cos(lat1) * sin(angularDistance) * cos(bearing)
        )
        let lon2 = lon1 + atan2(
            sin(bearing) * sin(angularDistance) * cos(lat1),
            cos(angularDistance) - sin(lat1) * sin(lat2)
        )

        return CLLocationCoordinate2D(
            latitude: lat2 * 180 / .pi,
            longitude: lon2 * 180 / .pi
        )
    }
}
#endif
