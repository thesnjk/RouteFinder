import Contracts
import CoreLocation
import CostModel
import Foundation
import NavigationCore
import RouteController

/// Immutable route and vehicle inputs for physics actor configuration.
public struct SimulationPhysicsConfiguration: Sendable {
  public let densifiedRoute: [Coordinate]
  public let segmentLengths: [Double]
  public let cumulativeLengths: [Double]
  public let totalRouteLength: Double
  public let routingCoordinates: [RoutingCoordinate]
  public let elevationProfile: ElevationProfile
  public let speedProfile: SimulationSpeedProfile
  public let speedLimitResolver: BoxedRouteSpeedLimitResolver
  public let transitionProfile: LongitudinalTransitionProfile
  public let vehicleMaxSpeedMps: Double
  /// Regional default speed floor when no explicit limit is available (m/s).
  public let defaultSpeedFloorMps: Double
  public let kineticStressProfile: KineticStressProfile
  public let dynamics: RouteDynamicsPhysics.SimulationVehicleDynamics
  public let environmentalContext: EnvironmentalContext
  public let vehicleWeightTonnes: Double?
  public let enginePowerHP: Double
  public let cruiseSpeedMps: Double
  public let isPassengerCarMode: Bool
  public let activeSpecificationProfile: VehicleSpecificationProfile?
  public let staticWebETASeconds: TimeInterval
  /// Minimum physical turn radius used as a floor for curve speed caps.
  public let minimumTurnRadiusMeters: Double?
  /// Turn instructions used for maneuver-aware physics cues.
  public let turnInstructions: [TurnInstruction]
  /// When true, TomTom congestion multipliers cap steady-state cruise speed.
  public let applyTrafficToSimulation: Bool

  /// Creates a physics configuration bundle.
  public init(
    densifiedRoute: [Coordinate],
    segmentLengths: [Double],
    cumulativeLengths: [Double],
    totalRouteLength: Double,
    routingCoordinates: [RoutingCoordinate],
    elevationProfile: ElevationProfile,
    speedProfile: SimulationSpeedProfile,
    speedLimitResolver: BoxedRouteSpeedLimitResolver,
    transitionProfile: LongitudinalTransitionProfile,
    vehicleMaxSpeedMps: Double,
    defaultSpeedFloorMps: Double,
    kineticStressProfile: KineticStressProfile,
    dynamics: RouteDynamicsPhysics.SimulationVehicleDynamics,
    environmentalContext: EnvironmentalContext,
    vehicleWeightTonnes: Double?,
    enginePowerHP: Double,
    cruiseSpeedMps: Double,
    isPassengerCarMode: Bool,
    activeSpecificationProfile: VehicleSpecificationProfile?,
    staticWebETASeconds: TimeInterval,
    minimumTurnRadiusMeters: Double? = nil,
    turnInstructions: [TurnInstruction] = [],
    applyTrafficToSimulation: Bool = false
  ) {
    self.densifiedRoute = densifiedRoute
    self.segmentLengths = segmentLengths
    self.cumulativeLengths = cumulativeLengths
    self.totalRouteLength = totalRouteLength
    self.routingCoordinates = routingCoordinates
    self.elevationProfile = elevationProfile
    self.speedProfile = speedProfile
    self.speedLimitResolver = speedLimitResolver
    self.transitionProfile = transitionProfile
    self.vehicleMaxSpeedMps = vehicleMaxSpeedMps
    self.defaultSpeedFloorMps = defaultSpeedFloorMps
    self.kineticStressProfile = kineticStressProfile
    self.dynamics = dynamics
    self.environmentalContext = environmentalContext
    self.vehicleWeightTonnes = vehicleWeightTonnes
    self.enginePowerHP = enginePowerHP
    self.cruiseSpeedMps = cruiseSpeedMps
    self.isPassengerCarMode = isPassengerCarMode
    self.activeSpecificationProfile = activeSpecificationProfile
    self.staticWebETASeconds = staticWebETASeconds
    self.minimumTurnRadiusMeters = minimumTurnRadiusMeters
    self.turnInstructions = turnInstructions
    self.applyTrafficToSimulation = applyTrafficToSimulation
  }

  /// Returns a copy with an updated vehicle specification profile and rebuilt telematics-driven dynamics.
  public func replacing(profile: VehicleSpecificationProfile) -> SimulationPhysicsConfiguration {
    let resolvedHP = profile.enginePowerHorsepower.map(Double.init) ?? enginePowerHP
    let telematics = PlateTelematicsPhysicsProfile.from(
      massKg: profile.grossWeightKilograms,
      powerHP: resolvedHP,
      wheelbaseMeters: profile.wheelbaseMeters,
      isPassengerCar: profile.vehicleClass == .passengerCar
    )
    let updatedDynamics = RouteDynamicsPhysics.SimulationVehicleDynamics.from(telematics: telematics)
    let path3D = densifiedRoute.map {
      GeoCoordinate3D(
        latitude: $0.latitude,
        longitude: $0.longitude,
        elevationMeters: $0.elevationMeters
      )
    }
    let rebuiltStress = KineticGradientAnalyzer.buildProfile(
      path: path3D,
      weightTons: telematics.weightTonnes
    )
    return SimulationPhysicsConfiguration(
      densifiedRoute: densifiedRoute,
      segmentLengths: segmentLengths,
      cumulativeLengths: cumulativeLengths,
      totalRouteLength: totalRouteLength,
      routingCoordinates: routingCoordinates,
      elevationProfile: elevationProfile,
      speedProfile: speedProfile,
      speedLimitResolver: speedLimitResolver,
      transitionProfile: transitionProfile,
      vehicleMaxSpeedMps: vehicleMaxSpeedMps,
      defaultSpeedFloorMps: defaultSpeedFloorMps,
      kineticStressProfile: rebuiltStress,
      dynamics: updatedDynamics,
      environmentalContext: environmentalContext,
      vehicleWeightTonnes: telematics.weightTonnes,
      enginePowerHP: telematics.powerHP,
      cruiseSpeedMps: cruiseSpeedMps,
      isPassengerCarMode: profile.vehicleClass == .passengerCar,
      activeSpecificationProfile: profile,
      staticWebETASeconds: staticWebETASeconds,
      minimumTurnRadiusMeters: minimumTurnRadiusMeters,
      turnInstructions: turnInstructions,
      applyTrafficToSimulation: applyTrafficToSimulation
    )
  }
}

/// Result returned when simulation playback reaches the route terminus.
public struct SimulationCompletionResult: Sendable {
  public let telemetryReport: PredictiveTelemetryReport

  /// Creates a completion result.
  public init(telemetryReport: PredictiveTelemetryReport) {
    self.telemetryReport = telemetryReport
  }
}

/// Actor-isolated physics integrator that runs off the main thread.
public actor SimulationPhysicsActor {
  private static let maxPoseSnapshots = 4
  private static let environmentPollInterval = 4
  private static let curveLookaheadBufferMeters = 15.0
  private static let launchSpeedThresholdMps = 0.5

  private let trafficSignalController = TrafficSignalController()
  private let trafficDataService: TrafficDataService
  private let telemetryRecorder = SimulationTelemetryRecorder()
  private let mailbox: SimulationStateMailbox

  private var configuration: SimulationPhysicsConfiguration?
  private var arcLengthSampler = RouteArcLengthSampler(
    densifiedRoute: [],
    segmentLengths: [],
    totalRouteLength: 0
  )

  private var arcLengthPosition: Double = 0
  private var speedMps: Double = 0
  private var headingDegrees: Double = 0
  private var simulationElapsedSeconds: TimeInterval = 0
  private var isRunning = false
  private var revision: UInt64 = 0

  private var topographyEngine = TopographicalGradientEngine()
  private var tireSlipTracker = TireSlipAndRollTracker(
    isPassengerCar: false,
    maxLateralG: 0.16
  )

  private var cachedTrafficMultiplier: Double = 1.0
  private var cachedSignalPermission = TrafficSignalPermission.unrestricted
  private var environmentPollCounter = 0
  private var environmentalContext: EnvironmentalContext = .dry

  private var isBrakingWarning = false
  private var isPausedForSignal = false
  private var brakeFadeRisk: BrakeFadeRisk?
  private var topographyState: TopographyGradientState?
  private var currentKineticStress: SegmentKineticStress?

  private var poseSnapshots: [SimulationPoseSnapshot] = []
  private var steeringSnapshot: CentripetalSpeedGovernor.SteeringSnapshot?
  private var activeLegalSpeedLimitKmh: Double?
  private var trafficAdjustedLimitKmh: Double?
  private var activeSpeedLimitSource: SpeedLimitSource = .regionalDefault
  private var velocityCapReason: VelocityCapReason = .legal
  private var previousLegalLimitMps: Double?

  /// Creates a physics actor with the shared state mailbox and traffic service.
  public init(
    tomTomAPIKey: String? = nil,
    mailbox: SimulationStateMailbox
  ) {
    trafficDataService = TrafficDataService(tomTomAPIKey: tomTomAPIKey)
    self.mailbox = mailbox
  }

  /// Configures route data and resets playback state.
  public func configure(_ config: SimulationPhysicsConfiguration) async {
    configuration = config
    arcLengthSampler = RouteArcLengthSampler(
      densifiedRoute: config.densifiedRoute,
      segmentLengths: config.segmentLengths,
      totalRouteLength: config.totalRouteLength
    )
    arcLengthPosition = 0
    speedMps = 0
    headingDegrees = initialHeading(from: config.densifiedRoute)
    simulationElapsedSeconds = 0
    isRunning = false
    revision = 0
    poseSnapshots = []
    environmentPollCounter = 0
    cachedTrafficMultiplier = 1.0
    cachedSignalPermission = .unrestricted
    isBrakingWarning = false
    environmentalContext = config.environmentalContext
    isPausedForSignal = false
    brakeFadeRisk = nil
    topographyState = nil
    currentKineticStress = nil
    topographyEngine.resetThermalLoad()
    tireSlipTracker = TireSlipAndRollTracker(
      isPassengerCar: config.isPassengerCarMode,
      maxLateralG: config.dynamics.lateralG,
      frictionCoefficient: config.environmentalContext.frictionCoefficient
    )

    let vehicleSpec = config.activeSpecificationProfile
      ?? VehicleSpecificationProfile.routingDefault(
        vehicleClass: config.isPassengerCarMode ? .passengerCar : .heavyGoodsVehicle
      )
    await trafficDataService.configureRoute(
      coordinates: config.routingCoordinates,
      cumulativeLengths: config.cumulativeLengths
    )
    await trafficDataService.configure(vehicleProfile: vehicleSpec)
    Task {
      await trafficSignalController.configureRoute(
        coordinates: config.routingCoordinates,
        cumulativeLengths: config.cumulativeLengths
      )
    }

    publishMailboxSnapshot()
    publishUIState()
  }

  /// Returns the active physics configuration, if configured.
  public func exportConfiguration() -> SimulationPhysicsConfiguration? {
    configuration
  }

  /// Resets telemetry for a new playback session.
  public func resetTelemetry() async {
    await telemetryRecorder.reset()
  }

  /// Marks simulation as running.
  public func start() {
    isRunning = true
    publishUIState()
  }

  /// Marks simulation as stopped.
  public func stop() {
    isRunning = false
    publishUIState()
  }

  /// Advances one fixed physics step and writes the latest snapshot to the mailbox.
  ///
  /// - Returns: Completion result when the route terminus is reached, otherwise `nil`.
  @discardableResult
  public func step(fixedDeltaTime: Double, simulationSpeedMultiplier: Double) async -> SimulationCompletionResult? {
    guard isRunning, let config = configuration, config.densifiedRoute.count >= 3, config.totalRouteLength > 0 else {
      return nil
    }

    let signpost = SimulationInstrumentation.beginPhysicsTick()
    defer { SimulationInstrumentation.endPhysicsTick(signpost) }

    let deltaSimulationTime = fixedDeltaTime * simulationSpeedMultiplier
    simulationElapsedSeconds += deltaSimulationTime
    await telemetryRecorder.advanceElapsedTime(deltaSimulationTime)

    if environmentPollCounter % Self.environmentPollInterval == 0 {
      await refreshEnvironmentCaches(wallClockDeltaTime: fixedDeltaTime, config: config)
    }
    environmentPollCounter &+= 1

    updateSteering(deltaTime: deltaSimulationTime, config: config)
    await advancePhysics(deltaTime: deltaSimulationTime, config: config)
    publishPoseSnapshot()
    revision &+= 1
    publishMailboxSnapshot()
    publishUIState()

    if arcLengthPosition >= config.totalRouteLength {
      isRunning = false
      publishUIState()
      return SimulationCompletionResult(telemetryReport: await buildTelemetryReport(config: config))
    }
    return nil
  }

  /// Advances one physics step with a fixed delta (unit tests and direct stepping).
  public func simulateTick(deltaTime: Double, simulationSpeedMultiplier: Double) async -> SimulationCompletionResult? {
    if !isRunning {
      isRunning = true
    }
    return await step(fixedDeltaTime: min(max(deltaTime, 0), 0.25), simulationSpeedMultiplier: simulationSpeedMultiplier)
  }

  /// Updates environmental context without resetting route position.
  public func updateEnvironmentalContext(_ context: EnvironmentalContext) {
    environmentalContext = context
    if let config = configuration {
      tireSlipTracker = TireSlipAndRollTracker(
        isPassengerCar: config.isPassengerCarMode,
        maxLateralG: config.dynamics.lateralG,
        frictionCoefficient: context.frictionCoefficient
      )
    }
  }

  /// Configures the traffic vehicle profile used by the traffic data service.
  public func configureVehicleProfile(_ profile: VehicleSpecificationProfile) async {
    if let config = configuration {
      configuration = config.replacing(profile: profile)
      tireSlipTracker = TireSlipAndRollTracker(
        isPassengerCar: profile.vehicleClass == .passengerCar,
        maxLateralG: configuration?.dynamics.lateralG ?? config.dynamics.lateralG,
        frictionCoefficient: environmentalContext.frictionCoefficient
      )
    }
    await trafficDataService.configure(vehicleProfile: profile)
  }

  /// Current arc length along the route in meters.
  public var currentArcLengthPosition: Double {
    arcLengthPosition
  }

  /// Current heading in degrees clockwise from north.
  public var currentHeadingDegrees: Double {
    headingDegrees
  }

  /// Elapsed simulation time in seconds.
  public var elapsedSimulationSeconds: TimeInterval {
    simulationElapsedSeconds
  }

  /// Whether playback is active.
  public var running: Bool {
    isRunning
  }

  private func refreshEnvironmentCaches(wallClockDeltaTime: Double, config: SimulationPhysicsConfiguration) async {
    let coordinate = arcLengthSampler.coordinate(at: arcLengthPosition)
    let routingCoord = RoutingCoordinate(latitude: coordinate.latitude, longitude: coordinate.longitude)
    cachedTrafficMultiplier = await trafficDataService.velocityMultiplier(atArcLength: arcLengthPosition)
    await trafficDataService.refreshTraffic(at: routingCoord, arcLength: arcLengthPosition)
    await trafficDataService.evictStaleSegments(vehicleCoordinate: routingCoord)

    let gradePercent = config.elevationProfile.gradePercent(atArcLength: arcLengthPosition)
    let effectiveDecel = EnvironmentalPhysics.effectiveMaxDecel(
      base: config.dynamics.maxDecelMps2,
      gradePercent: gradePercent,
      weightTonnes: config.vehicleWeightTonnes
    )
    cachedSignalPermission = await trafficSignalController.permittedSpeed(
      arcLength: arcLengthPosition,
      currentSpeedMps: speedMps,
      maxDecelMps2: effectiveDecel,
      deltaTime: wallClockDeltaTime
    )
  }

  private func advancePhysics(deltaTime: Double, config: SimulationPhysicsConfiguration) async {
    guard deltaTime > 0 else { return }

    let legalRoadLimitMps = config.speedLimitResolver.legalLimitMps(at: arcLengthPosition)
    let limitDetails = config.speedLimitResolver.limitDetails(at: arcLengthPosition)
    activeLegalSpeedLimitKmh = limitDetails.speedKmh
    activeSpeedLimitSource = limitDetails.source

    var roadLimitMps = legalRoadLimitMps > 0 ? legalRoadLimitMps : config.defaultSpeedFloorMps
    if let previous = previousLegalLimitMps {
      let delta = abs(previous - roadLimitMps)
      if delta <= config.transitionProfile.limitChangeHysteresisMps {
        roadLimitMps = previous
      }
    }
    previousLegalLimitMps = legalRoadLimitMps > 0 ? legalRoadLimitMps : config.defaultSpeedFloorMps

    let vLegalBase = min(roadLimitMps, config.vehicleMaxSpeedMps)
    let vLegal: Double
    if config.applyTrafficToSimulation {
      vLegal = vLegalBase * cachedTrafficMultiplier
      trafficAdjustedLimitKmh = limitDetails.speedKmh * cachedTrafficMultiplier
    } else {
      vLegal = vLegalBase
      trafficAdjustedLimitKmh = nil
    }
    let gradePercent = config.elevationProfile.gradePercent(atArcLength: arcLengthPosition)
    let effectiveDecel = EnvironmentalPhysics.effectiveMaxDecel(
      base: config.dynamics.maxDecelMps2,
      gradePercent: gradePercent,
      weightTonnes: config.vehicleWeightTonnes
    )
    let stoppingDistance = RouteDynamicsPhysics.stoppingDistanceMeters(
      speedMps: speedMps,
      deceleration: effectiveDecel
    )
    let curveLookahead = (stoppingDistance + Self.curveLookaheadBufferMeters)
      * environmentalContext.curveLookaheadMultiplier
    let vCurve = CentripetalSpeedGovernor.maxUpcomingCurveSpeedMps(
      cumulativeLengths: config.cumulativeLengths,
      coordinates: config.densifiedRoute,
      arcLength: arcLengthPosition,
      lookaheadM: curveLookahead,
      lateralG: config.dynamics.lateralG,
      friction: environmentalContext.frictionCoefficient,
      currentSpeedMps: speedMps,
      minimumTurnRadiusMeters: config.minimumTurnRadiusMeters,
      steeringSnapshot: steeringSnapshot
    )
    let vSignal = cachedSignalPermission.mustStop ? 0 : cachedSignalPermission.permittedSpeedMps
    let kineticStress = config.kineticStressProfile.stress(atArcLength: arcLengthPosition)
    currentKineticStress = kineticStress

    var vTarget = min(vLegal, vCurve, vSignal)
    velocityCapReason = Self.velocityCapReason(
      vLegal: vLegal,
      vCurve: vCurve,
      vCruise: config.cruiseSpeedMps,
      vSignal: vSignal,
      vTarget: vTarget
    )

    if !config.isPassengerCarMode,
       kineticStress.uphillLoadMultiplier > 1.0,
       gradePercent > EnvironmentalPhysics.steepUphillGradePercent
         || kineticStress.gradePercentage > EnvironmentalPhysics.steepUphillGradePercent {
      vTarget /= kineticStress.uphillLoadMultiplier
    }

    SimulationVelocityDiagnostics.logVelocityCap(
      arcLength: arcLengthPosition,
      vLegal: vLegal,
      legalLimitKmh: limitDetails.speedKmh,
      limitSource: limitDetails.source,
      measurementSystem: config.speedLimitResolver.regionalMeasurementSystem,
      vCurve: vCurve,
      vCruise: config.cruiseSpeedMps,
      vSignal: vSignal,
      vTarget: vTarget,
      simulationElapsedSeconds: simulationElapsedSeconds
    )

    let gradeLimitedAccel = LongitudinalGradeModel.effectiveAccelCapMps2(
      baseAccelMps2: config.dynamics.maxAccelMps2,
      gradePercent: gradePercent,
      uphillLoadMultiplier: kineticStress.uphillLoadMultiplier,
      weightTonnes: config.vehicleWeightTonnes
    )
    let massKg = resolvedVehicleMassKg(config: config)
    let thermalGradePercent = gradePercent * (1.0 + kineticStress.thermalStressScore)
    var gradientState = topographyEngine.advanceThermalLoad(
      gradePercent: thermalGradePercent,
      velocityMps: speedMps,
      massKg: massKg,
      deltaTime: deltaTime
    )
    gradientState = TopographyGradientState(
      gradeAngleDegrees: gradientState.gradeAngleDegrees,
      effectiveMaxAccelerationMps2: gradeLimitedAccel,
      thermalLoadJoules: gradientState.thermalLoadJoules,
      brakeFadeRisk: gradientState.brakeFadeRisk
    )
    topographyState = gradientState
    brakeFadeRisk = gradientState.brakeFadeRisk

    if gradientState.brakeFadeRisk != nil {
      let fadeEvent = SimulationEvent(
        kind: .brakeFade,
        arcLengthMeters: arcLengthPosition,
        elapsedSeconds: simulationElapsedSeconds,
        magnitude: gradientState.thermalLoadJoules
      )
      await telemetryRecorder.record(fadeEvent)
    }

    if speedMps < Self.launchSpeedThresholdMps {
      vTarget = max(vTarget, RouteDynamicsPhysics.launchCrawlSpeedMps)
    }

    isPausedForSignal = cachedSignalPermission.mustStop && speedMps > 0.1
    isBrakingWarning = speedMps > vTarget + 0.5 && vTarget < speedMps

    let previousSpeed = speedMps
    let engineCap = RouteDynamicsPhysics.accelerationFromEnginePowerMps2(
      powerHP: config.enginePowerHP,
      weightTonnes: config.vehicleWeightTonnes,
      currentSpeedMps: speedMps
    )
    let transition = config.transitionProfile
    let zoneAccel = transition.accelerationMps2
    let zoneDecel = transition.decelerationMps2
    let gradeInput = LongitudinalGradeInput(
      gradePercent: gradePercent,
      currentSpeedMps: speedMps,
      targetSpeedMps: vTarget,
      vehicleMassKg: massKg,
      isPassengerCar: config.isPassengerCarMode,
      baseAccelMps2: zoneAccel,
      baseDecelMps2: zoneDecel,
      uphillLoadMultiplier: kineticStress.uphillLoadMultiplier,
      brakeFadeRisk: gradientState.brakeFadeRisk,
      weightTonnes: config.vehicleWeightTonnes,
      engineAccelCapMps2: engineCap
    )
    let requiredDecel = cachedSignalPermission.requiredDecelerationMps2 > 0
      ? cachedSignalPermission.requiredDecelerationMps2
      : 0
    let integration = LongitudinalGradeModel.integrate(
      input: gradeInput,
      deltaTime: deltaTime,
      requiredDecelerationMps2: requiredDecel
    )
    speedMps = integration.newSpeedMps

    if previousSpeed - speedMps > 2.5 * deltaTime, cachedSignalPermission.mustStop || isBrakingWarning {
      let decelEvent = SimulationEvent(
        kind: .hardDeceleration,
        arcLengthMeters: arcLengthPosition,
        elapsedSeconds: simulationElapsedSeconds,
        magnitude: (previousSpeed - speedMps) / deltaTime
      )
      await telemetryRecorder.record(decelEvent)
    }

    if !isPausedForSignal {
      arcLengthPosition += speedMps * deltaTime
    }

    await recordLateralDynamics(deltaTime: deltaTime, config: config)

    if arcLengthPosition >= config.totalRouteLength {
      arcLengthPosition = config.totalRouteLength
      speedMps = 0
    }
  }

  private func recordLateralDynamics(deltaTime: Double, config: SimulationPhysicsConfiguration) async {
    guard config.densifiedRoute.count >= 3 else { return }
    let index = min(
      max(0, config.cumulativeLengths.firstIndex(where: { $0 >= arcLengthPosition }) ?? 1),
      config.densifiedRoute.count - 2
    )
    let radius = RouteDynamicsPhysics.turningRadiusMeters(
      p0: config.densifiedRoute[max(0, index - 1)],
      p1: config.densifiedRoute[index],
      p2: config.densifiedRoute[min(config.densifiedRoute.count - 1, index + 1)]
    )
    let events = tireSlipTracker.evaluate(
      speedMps: speedMps,
      turningRadiusMeters: radius,
      arcLengthMeters: arcLengthPosition,
      elapsedSeconds: simulationElapsedSeconds
    )
    for event in events {
      await telemetryRecorder.record(event)
    }
  }

  private func updateSteering(deltaTime: Double, config: SimulationPhysicsConfiguration) {
    guard deltaTime > 0 else { return }

    let tangentBearing = arcLengthSampler.bearingDegrees(at: arcLengthPosition)
    let center = arcLengthSampler.coordinate(at: arcLengthPosition)
    let coordinate = CLLocationCoordinate2D(latitude: center.latitude, longitude: center.longitude)
    let wheelbase = resolvedWheelbaseMeters(config: config)
    let targetWaypoint = lookAheadWaypoint(fromArcLength: arcLengthPosition, wheelbaseMeters: wheelbase, config: config)
    let currentState = KinematicVehicleState(
      position: coordinate,
      headingDegrees: headingDegrees,
      currentSpeedMetersPerSecond: speedMps
    )
    let updatedState = KineticPhysicsEngine.updateVehicleState(
      currentState: currentState,
      targetWaypoint: targetWaypoint,
      wheelbaseMeters: wheelbase,
      deltaTime: deltaTime
    )
    let steerAngle = KineticPhysicsEngine.steeringAngleRadians(
      currentState: currentState,
      targetWaypoint: targetWaypoint,
      wheelbaseMeters: wheelbase
    )
    steeringSnapshot = CentripetalSpeedGovernor.SteeringSnapshot(
      steerAngleRadians: steerAngle,
      wheelbaseMeters: wheelbase
    )
    let blendFactor = min(1, deltaTime * 4.0)
    headingDegrees = VehiclePoseInterpolator.angleLerp(
      from: updatedState.headingDegrees,
      to: tangentBearing,
      t: blendFactor
    )
  }

  private func publishPoseSnapshot() {
    let snapshot = SimulationPoseSnapshot(
      arcLengthMeters: arcLengthPosition,
      bearingDegrees: headingDegrees,
      speedMps: speedMps,
      wallClockTime: ContinuousClock.now,
      simulationTimeSeconds: simulationElapsedSeconds
    )
    poseSnapshots.append(snapshot)
    if poseSnapshots.count > Self.maxPoseSnapshots {
      poseSnapshots.removeFirst(poseSnapshots.count - Self.maxPoseSnapshots)
    }
  }

  private func publishMailboxSnapshot() {
    mailbox.writeDisplay(
      SimulationDisplaySnapshot(
        poseSnapshots: poseSnapshots,
        arcLengthMeters: arcLengthPosition,
        bearingDegrees: headingDegrees,
        speedMps: speedMps,
        revision: revision
      )
    )
  }

  private func publishUIState() {
    mailbox.writeUI(
      SimulationUIState(
        speedKmh: speedMps * 3.6,
        activeLegalSpeedLimitKmh: activeLegalSpeedLimitKmh,
        trafficAdjustedLimitKmh: trafficAdjustedLimitKmh,
        speedLimitSource: activeSpeedLimitSource,
        velocityCapReason: velocityCapReason,
        isBrakingWarning: isBrakingWarning,
        isPausedForSignal: isPausedForSignal,
        brakeFadeRisk: brakeFadeRisk,
        topographyState: topographyState,
        currentKineticStress: currentKineticStress,
        simulationElapsedSeconds: simulationElapsedSeconds,
        isRunning: isRunning
      )
    )
  }

  private static func velocityCapReason(
    vLegal: Double,
    vCurve: Double,
    vCruise: Double,
    vSignal: Double,
    vTarget: Double
  ) -> VelocityCapReason {
    let candidates: [(VelocityCapReason, Double)] = [
      (.legal, vLegal),
      (.curve, vCurve),
      (.cruise, vCruise),
      (.signal, vSignal),
    ]
    let binding = candidates.min { lhs, rhs in
      if lhs.1 == rhs.1 { return lhs.0.rawValue < rhs.0.rawValue }
      return lhs.1 < rhs.1
    }
    if let binding, abs(binding.1 - vTarget) < 0.01 {
      return binding.0
    }
    return .legal
  }

  private func buildTelemetryReport(config: SimulationPhysicsConfiguration) async -> PredictiveTelemetryReport {
    let counters = await telemetryRecorder.aggregatedCounters()
    let events = await telemetryRecorder.allEvents()
    return PredictiveTelemetryService.generateReport(
      staticWebETASeconds: config.staticWebETASeconds,
      kineticPhysicsETASeconds: simulationElapsedSeconds,
      events: events,
      thermalFadeIntegral: counters.thermalIntegral,
      lateralGExcessSeconds: counters.lateralGExcessSeconds,
      peakBrakeFadeRisk: counters.peakBrakeFadeRisk,
      vehicleWeightTonnes: config.vehicleWeightTonnes
    )
  }

  private func resolvedWheelbaseMeters(config: SimulationPhysicsConfiguration) -> Double {
    if let profile = config.activeSpecificationProfile {
      return profile.wheelbaseMeters
    }
    return config.isPassengerCarMode ? 2.7 : 6.5
  }

  private func resolvedVehicleMassKg(config: SimulationPhysicsConfiguration) -> Double {
    if let profileKg = config.activeSpecificationProfile?.grossWeightKilograms, profileKg > 0 {
      return config.isPassengerCarMode ? max(profileKg, 1200) : max(profileKg, 3500)
    }
    let fallbackKg = (config.vehicleWeightTonnes ?? 7.5) * 1000.0
    return config.isPassengerCarMode ? max(fallbackKg, 1200) : max(fallbackKg, 3500)
  }

  private func lookAheadWaypoint(
    fromArcLength arcLength: Double,
    wheelbaseMeters: Double,
    config: SimulationPhysicsConfiguration
  ) -> CLLocationCoordinate2D {
    let lookAheadMeters = max(wheelbaseMeters * 2.0, speedMps * 0.5, 5.0)
    let ahead = arcLengthSampler.coordinate(at: arcLength + lookAheadMeters)
    return CLLocationCoordinate2D(latitude: ahead.latitude, longitude: ahead.longitude)
  }

  private func initialHeading(from route: [Coordinate]) -> Double {
    guard route.count >= 2 else { return 0 }
    let from = route[0]
    let to = route[1]
    let lat1 = from.latitude * .pi / 180
    let lat2 = to.latitude * .pi / 180
    let dLon = (to.longitude - from.longitude) * .pi / 180
    let y = sin(dLon) * cos(lat2)
    let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
    let bearing = atan2(y, x) * 180 / .pi
    var value = bearing.truncatingRemainder(dividingBy: 360)
    if value < 0 { value += 360 }
    return value
  }
}
