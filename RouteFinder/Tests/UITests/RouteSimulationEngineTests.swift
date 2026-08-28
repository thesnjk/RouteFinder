import Contracts
import CoreLocation
import Foundation
import NavigationCore
import RouteController
import Testing
@testable import UI

@MainActor
struct RouteSimulationEngineTests {
  private func sampleRoute() -> [CLLocationCoordinate2D] {
    [
      CLLocationCoordinate2D(latitude: 51.5007, longitude: -0.1246),
      CLLocationCoordinate2D(latitude: 51.5017, longitude: -0.1200),
      CLLocationCoordinate2D(latitude: 51.5030, longitude: -0.1150),
      CLLocationCoordinate2D(latitude: 51.5050, longitude: -0.1100),
    ]
  }

  @Test func configureStoresVehicleDimensions() {
    let engine = RouteSimulationEngine()
    let profile = VehicleProfile(width: 2.55, length: 16.5)
    engine.configure(route: sampleRoute(), vehicle: profile, totalDuration: 600)

    #expect(engine.vehicleLengthMeters == 16.5)
    #expect(engine.vehicleWidthMeters == 2.55)
  }

  @Test func configureUsesDefaultsWhenDimensionsMissing() {
    let engine = RouteSimulationEngine()
    engine.configure(route: sampleRoute(), vehicle: .default, totalDuration: 600)

    #expect(engine.vehicleLengthMeters == 12.0)
    #expect(engine.vehicleWidthMeters == 2.55)
  }

  @Test func tickAdvancesCoordinateWhileRunning() async throws {
    let engine = RouteSimulationEngine()
    engine.configure(route: sampleRoute(), vehicle: .ukRigid26t, totalDuration: 120)
    let start = try #require(engine.currentCoordinate)
    let initialRevision = engine.playbackRevision

    engine.toggleSimulation()
    try await Task.sleep(for: .milliseconds(800))
    let end = try #require(engine.currentCoordinate)
    let moved = abs(end.latitude - start.latitude) + abs(end.longitude - start.longitude)
    let speedKmh = engine.currentSpeedKmh
    engine.toggleSimulation()

    #expect(engine.playbackRevision > initialRevision)
    #expect(moved > 0 || speedKmh > 0)
  }

  @Test func speedMultiplierAcceleratesElapsedTime() async {
    var route = sampleRoute()
    route.append(CLLocationCoordinate2D(latitude: 51.5100, longitude: -0.1000))
    route.append(CLLocationCoordinate2D(latitude: 51.5150, longitude: -0.0900))
    let profile = VehicleProfile.ukRigid26t
    let maneuvers = [
      ExternalManeuver(instruction: "Continue", distanceMeters: 50_000, durationSeconds: 3600),
    ]

    let slowEngine = RouteSimulationEngine()
    slowEngine.configure(
      route: route,
      vehicle: profile,
      totalDuration: 600,
      maneuvers: maneuvers,
      isPassengerCar: false
    )
    slowEngine.simulationSpeedMultiplier = 1.0
    for _ in 0..<20 { await slowEngine.simulateTick(deltaTime: 0.1) }
    let slowElapsed = slowEngine.elapsedSimulationSeconds

    let fastEngine = RouteSimulationEngine()
    fastEngine.configure(
      route: route,
      vehicle: profile,
      totalDuration: 600,
      maneuvers: maneuvers,
      isPassengerCar: false
    )
    fastEngine.simulationSpeedMultiplier = 10.0
    for _ in 0..<20 { await fastEngine.simulateTick(deltaTime: 0.1) }
    let fastElapsed = fastEngine.elapsedSimulationSeconds

    #expect(fastElapsed > slowElapsed * 5.0)
  }

  @Test func speedMultiplierRaisesPlaybackCap() async throws {
    var route = sampleRoute()
    route.append(CLLocationCoordinate2D(latitude: 51.5100, longitude: -0.1000))
    route.append(CLLocationCoordinate2D(latitude: 51.5150, longitude: -0.0900))
    let profile = VehicleProfile.ukRigid26t
    let maneuvers = [
      ExternalManeuver(instruction: "Continue", distanceMeters: 50_000, durationSeconds: 3600),
    ]

    let slowEngine = RouteSimulationEngine()
    slowEngine.configure(
      route: route,
      vehicle: profile,
      totalDuration: 600,
      maneuvers: maneuvers,
      isPassengerCar: false
    )
    slowEngine.simulationSpeedMultiplier = 1.0
    slowEngine.toggleSimulation()
    try await Task.sleep(for: .milliseconds(400))
    let slowCoordinate = try #require(slowEngine.currentCoordinate)
    slowEngine.toggleSimulation()

    let fastEngine = RouteSimulationEngine()
    fastEngine.configure(
      route: route,
      vehicle: profile,
      totalDuration: 600,
      maneuvers: maneuvers,
      isPassengerCar: false
    )
    fastEngine.simulationSpeedMultiplier = 10.0
    fastEngine.toggleSimulation()
    try await Task.sleep(for: .milliseconds(400))
    let fastCoordinate = try #require(fastEngine.currentCoordinate)
    fastEngine.toggleSimulation()

    let slowDistance = abs(slowCoordinate.latitude - route[0].latitude)
    let fastDistance = abs(fastCoordinate.latitude - route[0].latitude)
    #expect(fastDistance > slowDistance)
  }

  @Test func playbackRevisionIncrementsWhileRunning() async throws {
    let engine = RouteSimulationEngine()
    engine.configure(route: sampleRoute(), vehicle: .ukRigid26t, totalDuration: 120)
    let initialRevision = engine.playbackRevision

    engine.toggleSimulation()
    try await Task.sleep(for: .milliseconds(300))
    engine.toggleSimulation()

    #expect(engine.playbackRevision > initialRevision)
  }

  @Test func launchEscapesZeroCurveSpeedTrap() async throws {
    let engine = RouteSimulationEngine()
    engine.configure(
      route: sampleRoute(),
      vehicle: .ukArtic,
      totalDuration: 3600,
      enginePowerHP: 450
    )

    engine.toggleSimulation()
    try await Task.sleep(for: .milliseconds(500))
    let speedKmh = engine.currentSpeedKmh
    engine.toggleSimulation()

    #expect(speedKmh > 0)
  }

  @Test func enginePowerFallbackAcceleratesHeavyVehicle() async throws {
    let engine = RouteSimulationEngine()
    engine.configure(
      route: sampleRoute(),
      vehicle: VehicleProfile(weight: 44),
      totalDuration: 3600,
      enginePowerHP: 450
    )

    engine.toggleSimulation()
    try await Task.sleep(for: .milliseconds(400))
    let speedKmh = engine.currentSpeedKmh
    engine.toggleSimulation()

    #expect(speedKmh > 0)
  }

  @Test func legalLimitCapsStraightRoadSpeed() async {
    let engine = RouteSimulationEngine()
    engine.configure(
      route: sampleRoute(),
      vehicle: .default,
      totalDuration: 120,
      maneuvers: [
        ExternalManeuver(
          instruction: "Continue on High Street",
          distanceMeters: 5000,
          durationSeconds: 400
        ),
      ],
      turnInstructions: [
        TurnInstruction(
          maneuver: .straight,
          roadName: "High Street",
          distance: 5000,
          bearing: 90
        ),
      ],
      isPassengerCar: true
    )

    for _ in 0..<120 {
      await engine.simulateTick(deltaTime: 0.1)
    }

    #expect(engine.currentSpeedKmh <= 48.5)
  }

  @Test func spineSpeedLimitAcceleratesToMotorwayLimit() async {
    let coordinates = (0..<8).map { index in
      Coordinate(latitude: 52.628, longitude: 1.296 + Double(index) * 0.015)
    }
    let speedLimitsKmh: [Double?] = coordinates.indices.map { index in
      index < 3 ? 48.0 : 112.0
    }
    let canonical = RouteGeometryCanonicalizer.process(
      coordinates,
      simulationStepMeters: 25,
      speedLimitSource: SegmentSpeedLimitSource(
        rawGeometrySpeedLimitsKmh: speedLimitsKmh,
        stepSpeedRanges: []
      )
    )

    let engine = RouteSimulationEngine()
    engine.configure(
      route: coordinates,
      vehicle: .default,
      totalDuration: 3600,
      enginePowerHP: 250,
      isPassengerCar: true,
      canonicalGeometry: canonical
    )
    engine.simulationSpeedMultiplier = 20.0

    var peakSpeedKmh = 0.0
    for _ in 0..<200 {
      await engine.simulateTick(deltaTime: 0.1)
      peakSpeedKmh = max(peakSpeedKmh, engine.currentSpeedKmh)
    }

    #expect(engine.activeLegalSpeedLimitKmh == 112)
    #expect(peakSpeedKmh >= 105)
  }

  @Test func cruiseSpeedDoesNotCapBelowPostedLegalLimit() async {
    let coordinates = (0..<6).map { index in
      Coordinate(latitude: 52.628, longitude: 1.296 + Double(index) * 0.015)
    }
    let speedLimitsKmh: [Double?] = Array(repeating: 48.0, count: coordinates.count)
    let canonical = RouteGeometryCanonicalizer.process(
      coordinates,
      simulationStepMeters: 25,
      speedLimitSource: SegmentSpeedLimitSource(
        rawGeometrySpeedLimitsKmh: speedLimitsKmh,
        stepSpeedRanges: []
      )
    )

    let engine = RouteSimulationEngine()
    engine.configure(
      route: coordinates,
      vehicle: .default,
      totalDuration: 3600,
      enginePowerHP: 250,
      isPassengerCar: true,
      canonicalGeometry: canonical
    )
    engine.simulationSpeedMultiplier = 20.0

    for _ in 0..<150 {
      await engine.simulateTick(deltaTime: 0.1)
    }

    #expect(engine.currentSpeedKmh >= 40)
  }

  @Test func sharpBendSlowsHeavyVehicle() async {
    let bendRoute = [
      CLLocationCoordinate2D(latitude: 51.5000, longitude: -0.1300),
      CLLocationCoordinate2D(latitude: 51.5000, longitude: -0.1200),
      CLLocationCoordinate2D(latitude: 51.5000, longitude: -0.1100),
      CLLocationCoordinate2D(latitude: 51.4990, longitude: -0.1100),
      CLLocationCoordinate2D(latitude: 51.4980, longitude: -0.1100),
      CLLocationCoordinate2D(latitude: 51.4970, longitude: -0.1100),
    ]

    let engine = RouteSimulationEngine()
    engine.configure(
      route: bendRoute,
      vehicle: VehicleProfile(weight: 44),
      totalDuration: 60,
      enginePowerHP: 450,
      isPassengerCar: false
    )
    engine.speedMultiplier = .x10

    for _ in 0..<80 {
      await engine.simulateTick(deltaTime: 0.1)
    }

    #expect(engine.currentSpeedKmh < 52)
  }

  @Test func headingDoesNotSnapInstantlyOnBend() async {
    let bendRoute = [
      CLLocationCoordinate2D(latitude: 51.5000, longitude: -0.1300),
      CLLocationCoordinate2D(latitude: 51.5000, longitude: -0.1200),
      CLLocationCoordinate2D(latitude: 51.5000, longitude: -0.1100),
      CLLocationCoordinate2D(latitude: 51.4990, longitude: -0.1100),
      CLLocationCoordinate2D(latitude: 51.4980, longitude: -0.1100),
    ]

    let engine = RouteSimulationEngine()
    engine.configure(route: bendRoute, vehicle: .ukArtic, totalDuration: 120)
    engine.simulationSpeedMultiplier = 10.0

    var previousBearing = engine.currentBearing
    var maxStep = 0.0
    for _ in 0..<30 {
      await engine.simulateTick(deltaTime: 0.1)
      let step = abs(engine.currentBearing - previousBearing)
      let wrapped = step > 180 ? 360 - step : step
      maxStep = max(maxStep, wrapped)
      previousBearing = engine.currentBearing
    }

    #expect(maxStep > 0.0)
    #expect(maxStep < 45.0)
  }

  @Test func headingMatchesEastboundSegment() async {
    let eastRoute = [
      CLLocationCoordinate2D(latitude: 51.5000, longitude: -0.1300),
      CLLocationCoordinate2D(latitude: 51.5000, longitude: -0.1200),
      CLLocationCoordinate2D(latitude: 51.5000, longitude: -0.1100),
    ]

    let engine = RouteSimulationEngine()
    engine.configure(route: eastRoute, vehicle: .ukArtic, totalDuration: 120)
    engine.simulationSpeedMultiplier = 5.0

    for _ in 0..<20 {
      await engine.simulateTick(deltaTime: 0.1)
    }

    #expect(engine.currentBearing > 85)
    #expect(engine.currentBearing < 95)
  }

  @Test func headingMatchesSouthboundSegment() async {
    let southRoute = [
      CLLocationCoordinate2D(latitude: 51.5000, longitude: -0.1100),
      CLLocationCoordinate2D(latitude: 51.4990, longitude: -0.1100),
      CLLocationCoordinate2D(latitude: 51.4980, longitude: -0.1100),
    ]

    let engine = RouteSimulationEngine()
    engine.configure(route: southRoute, vehicle: .ukArtic, totalDuration: 120)
    engine.simulationSpeedMultiplier = 5.0

    for _ in 0..<20 {
      await engine.simulateTick(deltaTime: 0.1)
    }

    #expect(engine.currentBearing > 175)
    #expect(engine.currentBearing < 185)
  }

  @Test func wheelbaseUsesProfileClassDefaults() {
    let engine = RouteSimulationEngine()
    engine.configure(
      route: sampleRoute(),
      vehicle: VehicleProfile(width: 2.55, length: 16.0),
      totalDuration: 600
    )

    #expect(abs(engine.wheelbaseMeters - 6.5) < 0.01)

    let carEngine = RouteSimulationEngine()
    carEngine.configure(
      route: sampleRoute(),
      vehicle: .default,
      totalDuration: 600,
      isPassengerCar: true
    )

    #expect(abs(carEngine.wheelbaseMeters - 2.7) < 0.01)
  }

  @Test func icyConditionsReduceSpeedOnBend() async {
    let bendRoute = [
      CLLocationCoordinate2D(latitude: 51.5000, longitude: -0.1300),
      CLLocationCoordinate2D(latitude: 51.5000, longitude: -0.1200),
      CLLocationCoordinate2D(latitude: 51.5000, longitude: -0.1100),
      CLLocationCoordinate2D(latitude: 51.4990, longitude: -0.1100),
      CLLocationCoordinate2D(latitude: 51.4980, longitude: -0.1100),
      CLLocationCoordinate2D(latitude: 51.4970, longitude: -0.1100),
    ]

    let dryEngine = RouteSimulationEngine()
    dryEngine.configure(
      route: bendRoute,
      environmentalContext: .dry,
      vehicle: VehicleProfile(weight: 44),
      totalDuration: 60,
      enginePowerHP: 450,
      isPassengerCar: false
    )
    dryEngine.speedMultiplier = .x10
    for _ in 0..<80 { await dryEngine.simulateTick(deltaTime: 0.1) }
    let drySpeed = dryEngine.currentSpeedKmh

    let iceEngine = RouteSimulationEngine()
    iceEngine.configure(
      route: bendRoute,
      environmentalContext: .ice,
      vehicle: VehicleProfile(weight: 44),
      totalDuration: 60,
      enginePowerHP: 450,
      isPassengerCar: false
    )
    iceEngine.speedMultiplier = .x10
    for _ in 0..<80 { await iceEngine.simulateTick(deltaTime: 0.1) }
    let iceSpeed = iceEngine.currentSpeedKmh

    #expect(iceSpeed <= drySpeed)
  }

  @Test func elevationProfileTracksMaxGrade() {
    let route = [
      CLLocationCoordinate2D(latitude: 51.5000, longitude: -0.1200),
      CLLocationCoordinate2D(latitude: 51.5000, longitude: -0.1190),
      CLLocationCoordinate2D(latitude: 51.5000, longitude: -0.1180),
    ]
    let elevations: [Double?] = [100, 106, 106]

    let engine = RouteSimulationEngine()
    engine.configure(
      route: route,
      elevations: elevations,
      vehicle: .ukArtic,
      totalDuration: 120
    )

    #expect(engine.maxRouteGradePercent > 0)
  }

  @Test func uphillKineticStressReducesSpeed() async {
    var route = sampleRoute()
    route.append(CLLocationCoordinate2D(latitude: 51.5100, longitude: -0.1000))
    route.append(CLLocationCoordinate2D(latitude: 51.5150, longitude: -0.0900))
    let elevations: [Double?] = [0, 20, 40, 60, 80, 100]
    let maneuvers = [
      ExternalManeuver(instruction: "Continue", distanceMeters: 100_000, durationSeconds: 3600),
    ]

    let neutralProfile = KineticStressProfile(
      segments: [SegmentKineticStress(gradePercentage: 0, thermalStressScore: 0, loadMultiplier: 1)],
      segmentStartArcLengths: [0, 100_000]
    )
    let uphillProfile = KineticStressProfile(
      segments: [
        SegmentKineticStress(gradePercentage: 8, thermalStressScore: 0, loadMultiplier: 3.0),
      ],
      segmentStartArcLengths: [0, 100_000]
    )

    let neutralEngine = RouteSimulationEngine()
    neutralEngine.configure(
      route: route,
      elevations: elevations,
      vehicle: VehicleProfile.ukRigid26t,
      totalDuration: 600,
      maneuvers: maneuvers,
      isPassengerCar: false,
      kineticStressProfile: neutralProfile
    )
    neutralEngine.speedMultiplier = .x10
    for _ in 0..<25 { await neutralEngine.simulateTick(deltaTime: 0.1) }
    let neutralSpeed = neutralEngine.currentSpeedKmh

    let uphillEngine = RouteSimulationEngine()
    uphillEngine.configure(
      route: route,
      elevations: elevations,
      vehicle: VehicleProfile.ukRigid26t,
      totalDuration: 600,
      maneuvers: maneuvers,
      isPassengerCar: false,
      kineticStressProfile: uphillProfile
    )
    uphillEngine.speedMultiplier = .x10
    for _ in 0..<25 { await uphillEngine.simulateTick(deltaTime: 0.1) }
    let uphillSpeed = uphillEngine.currentSpeedKmh

    #expect(neutralSpeed > 0)
    #expect(uphillEngine.currentKineticStress?.loadMultiplier == 3.0)
    #expect(uphillSpeed < neutralSpeed)
  }

  @Test func passengerCarMaintainsSpeedOnDownhillGrade() async {
    let route = [
      CLLocationCoordinate2D(latitude: 51.5000, longitude: -0.1200),
      CLLocationCoordinate2D(latitude: 51.5000, longitude: -0.1100),
      CLLocationCoordinate2D(latitude: 51.5000, longitude: -0.1000),
      CLLocationCoordinate2D(latitude: 51.5000, longitude: -0.0900),
      CLLocationCoordinate2D(latitude: 51.5000, longitude: -0.0800),
    ]
    let elevations: [Double?] = [300, 250, 200, 150, 100]
    let maneuvers = [
      ExternalManeuver(instruction: "Continue", distanceMeters: 100_000, durationSeconds: 3600),
    ]

    let downhillProfile = KineticStressProfile(
      segments: [
        SegmentKineticStress(gradePercentage: -8, thermalStressScore: 0.5, loadMultiplier: 0.2),
      ],
      segmentStartArcLengths: [0, 100_000]
    )

    let engine = RouteSimulationEngine()
    engine.configure(
      route: route,
      elevations: elevations,
      vehicle: .default,
      totalDuration: 500,
      maneuvers: maneuvers,
      isPassengerCar: true,
      kineticStressProfile: downhillProfile
    )
    engine.speedMultiplier = .x10

    for _ in 0..<50 {
      await engine.simulateTick(deltaTime: 0.1)
    }

    #expect(engine.currentSpeedKmh > 17)
  }
}
