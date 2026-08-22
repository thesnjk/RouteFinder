import CoreLocation
import Foundation

/// Kinematic state of a vehicle at a single simulation frame.
public struct KinematicVehicleState: Sendable {
    /// Rear-axle position in WGS84.
    public var position: CLLocationCoordinate2D
    /// Heading in degrees clockwise from north.
    public var headingDegrees: Double
    /// Longitudinal speed in meters per second.
    public var currentSpeedMetersPerSecond: Double

    /// Creates a kinematic vehicle state.
    public init(
        position: CLLocationCoordinate2D,
        headingDegrees: Double,
        currentSpeedMetersPerSecond: Double
    ) {
        self.position = position
        self.headingDegrees = headingDegrees
        self.currentSpeedMetersPerSecond = currentSpeedMetersPerSecond
    }
}

/// Analytical Ackermann bicycle-model vehicle motion integrator.
public enum KineticPhysicsEngine: Sendable {
    private static let metersPerDegreeLatitude: Double = 111_320.0
    private static let maxSteerAngleDegrees: Double = 35.0

    /// Computes the next simulation frame using Ackermann vehicle tracking mechanics.
    ///
    /// The model derives heading change from wheel articulation over the wheelbase distance
    /// and projects displacement from the rear-axle tracking line.
    ///
    /// - Parameters:
    ///   - currentState: Current rear-axle position, heading, and speed.
    ///   - targetWaypoint: Look-ahead waypoint on the route polyline.
    ///   - wheelbaseMeters: Distance between front and rear axles in meters.
    ///   - deltaTime: Integration timestep in seconds.
    /// - Returns: Updated kinematic state after one integration step.
    public static func updateVehicleState(
        currentState: KinematicVehicleState,
        targetWaypoint: CLLocationCoordinate2D,
        wheelbaseMeters: Double,
        deltaTime: Double
    ) -> KinematicVehicleState {
        let safeWheelbase = max(wheelbaseMeters, 0.1)
        let safeDeltaTime = max(deltaTime, 0.0)

        let latRad = currentState.position.latitude * Double.pi / 180.0
        let metersPerDegreeLongitude = Self.metersPerDegreeLatitude * cos(latRad)

        let deltaLatMeters = (targetWaypoint.latitude - currentState.position.latitude)
            * Self.metersPerDegreeLatitude
        let deltaLonMeters = (targetWaypoint.longitude - currentState.position.longitude)
            * metersPerDegreeLongitude

        let targetHeadingRadians = atan2(deltaLonMeters, deltaLatMeters)
        let currentHeadingRadians = currentState.headingDegrees * Double.pi / 180.0

        var steeringAngle = targetHeadingRadians - currentHeadingRadians
        while steeringAngle > Double.pi { steeringAngle -= 2.0 * Double.pi }
        while steeringAngle < -Double.pi { steeringAngle += 2.0 * Double.pi }

        let maxSteerAngleRadians = Self.maxSteerAngleDegrees * Double.pi / 180.0
        steeringAngle = max(min(steeringAngle, maxSteerAngleRadians), -maxSteerAngleRadians)

        let distanceMoved = currentState.currentSpeedMetersPerSecond * safeDeltaTime

        let headingChangeRadians = (distanceMoved / safeWheelbase) * sin(steeringAngle)
        let updatedHeadingRadians = currentHeadingRadians + headingChangeRadians

        let moveDistanceX = distanceMoved * sin(updatedHeadingRadians) * cos(steeringAngle)
        let moveDistanceY = distanceMoved * cos(updatedHeadingRadians) * cos(steeringAngle)

        let nextLatitude = currentState.position.latitude + (moveDistanceY / Self.metersPerDegreeLatitude)
        let nextLongitude = currentState.position.longitude + (moveDistanceX / metersPerDegreeLongitude)

        var finalHeadingDegrees = updatedHeadingRadians * 180.0 / Double.pi
        while finalHeadingDegrees < 0.0 { finalHeadingDegrees += 360.0 }
        while finalHeadingDegrees >= 360.0 { finalHeadingDegrees -= 360.0 }

        return KinematicVehicleState(
            position: CLLocationCoordinate2D(latitude: nextLatitude, longitude: nextLongitude),
            headingDegrees: finalHeadingDegrees,
            currentSpeedMetersPerSecond: currentState.currentSpeedMetersPerSecond
        )
    }

    /// Computes the clamped Ackermann steering angle toward a look-ahead waypoint.
    public static func steeringAngleRadians(
        currentState: KinematicVehicleState,
        targetWaypoint: CLLocationCoordinate2D,
        wheelbaseMeters: Double
    ) -> Double {
        _ = wheelbaseMeters
        let latRad = currentState.position.latitude * Double.pi / 180.0
        let metersPerDegreeLongitude = Self.metersPerDegreeLatitude * cos(latRad)

        let deltaLatMeters = (targetWaypoint.latitude - currentState.position.latitude)
            * Self.metersPerDegreeLatitude
        let deltaLonMeters = (targetWaypoint.longitude - currentState.position.longitude)
            * metersPerDegreeLongitude

        let targetHeadingRadians = atan2(deltaLonMeters, deltaLatMeters)
        let currentHeadingRadians = currentState.headingDegrees * Double.pi / 180.0

        var steeringAngle = targetHeadingRadians - currentHeadingRadians
        while steeringAngle > Double.pi { steeringAngle -= 2.0 * Double.pi }
        while steeringAngle < -Double.pi { steeringAngle += 2.0 * Double.pi }

        let maxSteerAngleRadians = Self.maxSteerAngleDegrees * Double.pi / 180.0
        return max(min(steeringAngle, maxSteerAngleRadians), -maxSteerAngleRadians)
    }
}
