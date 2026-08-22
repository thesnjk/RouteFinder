import Contracts
import CoreLocation
import CostModel
import Foundation
import NavigationCore
import RouteController
import Testing
@testable import UI

@MainActor
struct SimulationStateMailboxTests {
  @Test func mailboxRoundTripsDisplaySnapshot() {
    let mailbox = SimulationStateMailbox()
    let snapshot = SimulationDisplaySnapshot(
      poseSnapshots: [
        SimulationPoseSnapshot(
          arcLengthMeters: 10,
          bearingDegrees: 90,
          speedMps: 5,
          wallClockTime: ContinuousClock.now,
          simulationTimeSeconds: 0.1
        ),
      ],
      arcLengthMeters: 10,
      bearingDegrees: 90,
      speedMps: 5,
      revision: 1
    )

    mailbox.writeDisplay(snapshot)
    let read = mailbox.readDisplay()

    #expect(read == snapshot)
  }

  @Test func mailboxResetClearsState() {
    let mailbox = SimulationStateMailbox()
    mailbox.writeUI(
      SimulationUIState(
        speedKmh: 30,
        isBrakingWarning: false,
        isPausedForSignal: false,
        brakeFadeRisk: nil,
        topographyState: nil,
        currentKineticStress: nil,
        simulationElapsedSeconds: 1,
        isRunning: true
      )
    )

    mailbox.reset()

    #expect(mailbox.readUI() == nil)
    #expect(mailbox.readDisplay() == nil)
  }
}

@MainActor
struct SimulationPhysicsActorTests {
  private func sampleConfig() -> SimulationPhysicsConfiguration {
    let route = [
      Coordinate(latitude: 51.5007, longitude: -0.1246),
      Coordinate(latitude: 51.5017, longitude: -0.1200),
      Coordinate(latitude: 51.5030, longitude: -0.1150),
      Coordinate(latitude: 51.5050, longitude: -0.1100),
    ]
    let segmentLengths = zip(route, route.dropFirst()).map { from, to in
      let earthRadius = 6_371_000.0
      let lat1 = from.latitude * .pi / 180
      let lat2 = to.latitude * .pi / 180
      let deltaLat = (to.latitude - from.latitude) * .pi / 180
      let deltaLon = (to.longitude - from.longitude) * .pi / 180
      let sinDLat = sin(deltaLat / 2)
      let sinDLon = sin(deltaLon / 2)
      let h = sinDLat * sinDLat + cos(lat1) * cos(lat2) * sinDLon * sinDLon
      return 2 * earthRadius * atan2(sqrt(h), sqrt(max(0, 1 - h)))
    }
    var cumulative: [Double] = [0]
    for length in segmentLengths {
      cumulative.append(cumulative.last! + length)
    }
    let total = segmentLengths.reduce(0, +)

    let speedProfile = SimulationSpeedProfile()

    return SimulationPhysicsConfiguration(
      densifiedRoute: route,
      segmentLengths: segmentLengths,
      cumulativeLengths: cumulative,
      totalRouteLength: total,
      routingCoordinates: route.map {
        RoutingCoordinate(latitude: $0.latitude, longitude: $0.longitude)
      },
      elevationProfile: ElevationProfile(coordinates: route),
      speedProfile: speedProfile,
      speedLimitResolver: BoxedRouteSpeedLimitResolver(speedProfile),
      transitionProfile: .standard,
      vehicleMaxSpeedMps: 96 / 3.6,
      defaultSpeedFloorMps: 48 / 3.6,
      kineticStressProfile: KineticStressProfile(segments: [], segmentStartArcLengths: []),
      dynamics: .forVehicle(weightTonnes: 44, isPassengerCar: false),
      environmentalContext: .dry,
      vehicleWeightTonnes: 44,
      enginePowerHP: 450,
      cruiseSpeedMps: 20,
      isPassengerCarMode: false,
      activeSpecificationProfile: nil,
      staticWebETASeconds: 120
    )
  }

  @Test func actorStepWritesMailboxSnapshot() async {
    let mailbox = SimulationStateMailbox()
    let actor = SimulationPhysicsActor(mailbox: mailbox)
    await actor.configure(sampleConfig())
    await actor.start()

    _ = await actor.step(fixedDeltaTime: 1.0 / 60.0, simulationSpeedMultiplier: 1.0)

    let snapshot = mailbox.readDisplay()
    #expect(snapshot != nil)
    #expect(snapshot?.revision == 1)
    #expect((snapshot?.speedMps ?? 0) >= 0)
  }
}

struct VehiclePoseInterpolatorTests {
  @Test func interpolatesUsingSimulationTimeline() {
    let route = [
      Coordinate(latitude: 51.5000, longitude: -0.1200),
      Coordinate(latitude: 51.5000, longitude: -0.1100),
      Coordinate(latitude: 51.5000, longitude: -0.1000),
    ]
    let segmentLengths = zip(route, route.dropFirst()).map { from, to in
      let earthRadius = 6_371_000.0
      let lat1 = from.latitude * .pi / 180
      let lat2 = to.latitude * .pi / 180
      let deltaLat = (to.latitude - from.latitude) * .pi / 180
      let deltaLon = (to.longitude - from.longitude) * .pi / 180
      let sinDLat = sin(deltaLat / 2)
      let sinDLon = sin(deltaLon / 2)
      let h = sinDLat * sinDLat + cos(lat1) * cos(lat2) * sinDLon * sinDLon
      return 2 * earthRadius * atan2(sqrt(h), sqrt(max(0, 1 - h)))
    }
    let total = segmentLengths.reduce(0, +)
    let sampler = RouteArcLengthSampler(
      densifiedRoute: route,
      segmentLengths: segmentLengths,
      totalRouteLength: total
    )
    let interpolator = VehiclePoseInterpolator(sampler: sampler)
    let now = ContinuousClock.now
    let earlier = SimulationPoseSnapshot(
      arcLengthMeters: 0,
      bearingDegrees: 90,
      speedMps: 10,
      wallClockTime: now,
      simulationTimeSeconds: 0
    )
    let later = SimulationPoseSnapshot(
      arcLengthMeters: 100,
      bearingDegrees: 90,
      speedMps: 10,
      wallClockTime: now,
      simulationTimeSeconds: 1.0
    )

    let midpoint = interpolator.interpolate(
      from: earlier,
      to: later,
      at: now,
      displaySimulationTimeSeconds: 0.5
    )

    #expect(midpoint.coordinate.longitude > route[0].longitude)
    #expect(midpoint.coordinate.longitude < route[2].longitude)
  }
}
