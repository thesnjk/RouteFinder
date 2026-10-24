import CoreLocation
import Foundation
import RouteController
import Testing

struct KineticPhysicsEngineTests {
    private func londonCoordinate() -> CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: 51.5007, longitude: -0.1246)
    }

    private func eastWaypoint(from origin: CLLocationCoordinate2D) -> CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: origin.latitude, longitude: origin.longitude + 0.01)
    }

    @Test func zeroSpeedPreservesHeading() {
        let origin = londonCoordinate()
        let state = KinematicVehicleState(
            position: origin,
            headingDegrees: 90.0,
            currentSpeedMetersPerSecond: 0.0
        )
        let updated = KineticPhysicsEngine.updateVehicleState(
            currentState: state,
            targetWaypoint: eastWaypoint(from: origin),
            wheelbaseMeters: 6.5,
            deltaTime: 0.1
        )

        #expect(updated.headingDegrees == 90.0)
        #expect(updated.position.latitude == origin.latitude)
        #expect(updated.position.longitude == origin.longitude)
    }

    @Test func headingChangesWhenMovingTowardWaypoint() {
        let origin = londonCoordinate()
        let state = KinematicVehicleState(
            position: origin,
            headingDegrees: 0.0,
            currentSpeedMetersPerSecond: 10.0
        )
        let updated = KineticPhysicsEngine.updateVehicleState(
            currentState: state,
            targetWaypoint: eastWaypoint(from: origin),
            wheelbaseMeters: 6.5,
            deltaTime: 0.5
        )

        #expect(updated.headingDegrees > 0.0)
        #expect(updated.headingDegrees < 90.0)
    }

    @Test func longerWheelbaseProducesSlowerHeadingChange() {
        let origin = londonCoordinate()
        let waypoint = eastWaypoint(from: origin)
        let shortBaseState = KinematicVehicleState(
            position: origin,
            headingDegrees: 0.0,
            currentSpeedMetersPerSecond: 12.0
        )
        let longBaseState = shortBaseState

        let shortBaseUpdate = KineticPhysicsEngine.updateVehicleState(
            currentState: shortBaseState,
            targetWaypoint: waypoint,
            wheelbaseMeters: 2.7,
            deltaTime: 0.2
        )
        let longBaseUpdate = KineticPhysicsEngine.updateVehicleState(
            currentState: longBaseState,
            targetWaypoint: waypoint,
            wheelbaseMeters: 6.5,
            deltaTime: 0.2
        )

        #expect(shortBaseUpdate.headingDegrees > longBaseUpdate.headingDegrees)
    }

    @Test func steeringAngleClampedAt35Degrees() {
        let origin = londonCoordinate()
        let southWaypoint = CLLocationCoordinate2D(latitude: origin.latitude - 0.05, longitude: origin.longitude)
        let state = KinematicVehicleState(
            position: origin,
            headingDegrees: 0.0,
            currentSpeedMetersPerSecond: 20.0
        )
        let wheelbaseMeters = 2.7
        let deltaTime = 0.1

        let updated = KineticPhysicsEngine.updateVehicleState(
            currentState: state,
            targetWaypoint: southWaypoint,
            wheelbaseMeters: wheelbaseMeters,
            deltaTime: deltaTime
        )

        let maxSteerRadians = 35.0 * Double.pi / 180.0
        let maxHeadingChangeRadians = (20.0 * deltaTime / wheelbaseMeters) * sin(maxSteerRadians)
        let maxHeadingChangeDegrees = maxHeadingChangeRadians * 180.0 / Double.pi

        #expect(updated.headingDegrees <= maxHeadingChangeDegrees + 0.5)
    }

    @Test func negativeSpeedProducesNoReverseDisplacement() {
        let origin = londonCoordinate()
        let state = KinematicVehicleState(
            position: origin,
            headingDegrees: 90.0,
            currentSpeedMetersPerSecond: -12.0
        )
        let updated = KineticPhysicsEngine.updateVehicleState(
            currentState: state,
            targetWaypoint: eastWaypoint(from: origin),
            wheelbaseMeters: 6.5,
            deltaTime: 0.5
        )

        #expect(abs(updated.position.latitude - origin.latitude) < 1e-12)
        #expect(abs(updated.position.longitude - origin.longitude) < 1e-12)
        #expect(updated.headingDegrees == 90.0)
        #expect(updated.currentSpeedMetersPerSecond == 0.0)
    }

    @Test func steeredTurnLeavesChordNotLateralSlide() {
        // Start facing north; steer toward a waypoint east and ahead.
        let origin = londonCoordinate()
        var state = KinematicVehicleState(
            position: origin,
            headingDegrees: 0.0,
            currentSpeedMetersPerSecond: 15.0
        )
        let waypoint = CLLocationCoordinate2D(
            latitude: origin.latitude + 0.002,
            longitude: origin.longitude + 0.002
        )

        for _ in 0..<30 {
            state = KineticPhysicsEngine.updateVehicleState(
                currentState: state,
                targetWaypoint: waypoint,
                wheelbaseMeters: 6.5,
                deltaTime: 0.1
            )
        }

        // Arc path: both lat and lon change; not a pure lateral (east-only) slide at heading 0.
        #expect(state.position.latitude > origin.latitude)
        #expect(state.position.longitude > origin.longitude)
        #expect(state.headingDegrees > 5.0)
        #expect(state.headingDegrees < 90.0)
    }
}
