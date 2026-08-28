import Combine
import Contracts
import CoreLocation
import CostModel
import Foundation
import MapLibreUI
import NavigationCore
import RouteController

/// Playback speed multiplier for route simulation.
public enum SpeedMultiplier: Double, CaseIterable, Identifiable, Sendable {
  case x1 = 1
  case x5 = 5
  case x10 = 10
  case x50 = 50

  public var id: Double { rawValue }

  /// Display label for picker UI.
  public var label: String {
    switch self {
    case .x1: return "1×"
    case .x5: return "5×"
    case .x10: return "10×"
    case .x50: return "50×"
    }
  }

  /// Maps a scalar multiplier to the nearest discrete preset.
  public static func closest(to value: Double) -> SpeedMultiplier {
    allCases.min(by: { abs($0.rawValue - value) < abs($1.rawValue - value) }) ?? .x1
  }
}

/// Physics-based route simulation that advances a vehicle along the route polyline.
@MainActor
public final class RouteSimulationEngine: ObservableObject {
  @Published public private(set) var isRunning = false
  @Published public var simulationSpeedMultiplier: Double = 1.0
  @Published public private(set) var currentCoordinate: CLLocationCoordinate2D?
  @Published public private(set) var currentBearing: Double = 0
  @Published public private(set) var currentSpeedKmh: Double = 0
  @Published public private(set) var activeLegalSpeedLimitKmh: Double?
  @Published public private(set) var trafficAdjustedLimitKmh: Double?
  @Published public private(set) var activeSpeedLimitSource: SpeedLimitSource = .regionalDefault
  @Published public private(set) var isBrakingWarning = false
  @Published public private(set) var playbackRevision: UInt64 = 0
  @Published public private(set) var isPausedForSignal = false
  @Published public private(set) var brakeFadeRisk: BrakeFadeRisk?
  @Published public private(set) var topographyState: TopographyGradientState?
  @Published public private(set) var currentKineticStress: SegmentKineticStress?
  @Published public private(set) var telemetryReport: PredictiveTelemetryReport?

  /// Optional callback invoked on each display frame during simulation playback.
  public var onDisplayFrameTick: (() -> Void)?
  /// Optional callback when published simulation UI state changes (kinetic advisories).
  public var onUIStatePublished: ((SimulationUIState) -> Void)?
  /// Optional callback invoked when simulation playback starts.
  public var onSimulationStarted: (() -> Void)?
  /// Awaitable hook invoked before the display clock starts (e.g. navigation telemetry activation).
  public var onSimulationStarting: (() async -> Void)?
  /// Optional callback invoked when simulation playback stops.
  public var onSimulationStopped: (() -> Void)?

  /// Current arc length along the route in meters during simulation playback.
  public var currentArcLengthMeters: Double {
    currentArcLengthStorage
  }

  /// Vehicle length in meters from the active profile (default 12.0 m).
  public private(set) var vehicleLengthMeters: Double = 12.0
  /// Vehicle width in meters from the active profile (default 2.55 m).
  public private(set) var vehicleWidthMeters: Double = 2.55
  /// Revision bumped when vehicle dimensions change to force map bridge updates.
  public private(set) var dimensionRevision: UInt64 = 0

  private var densifiedRoute: [Coordinate] = []
  private var segmentLengths: [Double] = []
  private var cumulativeLengths: [Double] = []
  private var totalRouteLength: Double = 0
  private var cruiseSpeedMps: Double = 20
  private var vehicleWeightTonnes: Double?
  private var enginePowerHP: Double = RouteDynamicsPhysics.defaultEnginePowerHP
  private var dynamics: RouteDynamicsPhysics.SimulationVehicleDynamics = .forVehicle(
    weightTonnes: nil,
    isPassengerCar: false
  )
  private var environmentalContext: EnvironmentalContext = .dry
  private var elevationProfile = ElevationProfile(coordinates: [])
  private var speedProfile = SimulationSpeedProfile()
  private var kineticStressProfile = KineticStressProfile(segments: [], segmentStartArcLengths: [])
  private var routingCoordinates: [RoutingCoordinate] = []
  private var staticWebETASeconds: TimeInterval = 0
  private var simulationElapsedSeconds: TimeInterval = 0
  private var isPassengerCarMode = false
  private var applyTrafficToSimulation = false
  private var activeSpecificationProfile: VehicleSpecificationProfile?

  private let mailbox = SimulationStateMailbox()
  private let physicsActor: SimulationPhysicsActor
  private var displayClock = SimulationDisplayClock()
  private var poseInterpolator: VehiclePoseInterpolator?
  private var arcLengthSampler = RouteArcLengthSampler(
    densifiedRoute: [],
    segmentLengths: [],
    totalRouteLength: 0
  )

  private var physicsAccumulator: Double = 0
  private var pendingPhysicsSteps = 0
  private var physicsDrainInFlight = false
  private var lastPublishedUIInstant: ContinuousClock.Instant?
  private var bridgeRevision: UInt64 = 0
  private var displaySimulationTime: Double = 0
  private var lastBridgeLatitude: Double?
  private var lastBridgeLongitude: Double?
  private var lastBridgeBearing: Double?
  private var configureTask: Task<Void, Never>?
  private var currentArcLengthStorage: Double = 0

  private let physicsStepSeconds = 1.0 / 60.0
  private let maxCatchUpStepsPerFrame = 4
  private let uiPublishMinIntervalSeconds = 1.0 / 30.0
  private let bridgeCoordinateDeltaThreshold = 0.000005
  private let bridgeBearingDeltaThreshold = 0.5
  private let minimumCruiseSpeedMps = 5.0

  /// Last route configure inputs for rebuilding after vehicle specification changes.
  private var lastConfigureManeuvers: [ExternalManeuver] = []
  private var lastConfigureTurnInstructions: [TurnInstruction] = []
  private var lastConfigureEnvironmentalContext: EnvironmentalContext = .dry
  private var lastConfigureVehicle: VehicleProfile = .default
  private var lastConfigureTotalDuration: TimeInterval = 0
  private var lastConfigureEnginePowerHP: Double = RouteDynamicsPhysics.defaultEnginePowerHP
  private var lastConfigureTomTomAPIKey: String?
  private var lastConfigureMinimumTurnRadiusMeters: Double?
  private var lastRouteCoordinates: [Coordinate] = []

  /// Discrete speed preset bridged to `simulationSpeedMultiplier`.
  public var speedMultiplier: SpeedMultiplier {
    get { SpeedMultiplier.closest(to: simulationSpeedMultiplier) }
    set { simulationSpeedMultiplier = newValue.rawValue }
  }

  /// Elapsed simulation time in seconds (scaled by playback multiplier).
  public var elapsedSimulationSeconds: TimeInterval {
    simulationElapsedSeconds
  }

  /// Total configured route length in meters.
  public var totalRouteLengthMeters: Double {
    totalRouteLength
  }

  /// Wheelbase in meters for Ackermann bicycle-model steering.
  public var wheelbaseMeters: Double {
    resolvedWheelbaseMeters()
  }

  public init(tomTomAPIKey: String? = nil) {
    physicsActor = SimulationPhysicsActor(tomTomAPIKey: tomTomAPIKey, mailbox: mailbox)
  }

  /// Configures the simulation for a new route and resets playback state.
  public func configure(
    route: [Coordinate],
    environmentalContext: EnvironmentalContext = .dry,
    vehicle: VehicleProfile,
    totalDuration: TimeInterval,
    enginePowerHP: Double = RouteDynamicsPhysics.defaultEnginePowerHP,
    maneuvers: [ExternalManeuver] = [],
    turnInstructions: [TurnInstruction] = [],
    isPassengerCar: Bool = false,
    tomTomAPIKey: String? = nil,
    vehicleSpecificationProfile: VehicleSpecificationProfile? = nil,
    kineticStressProfile: KineticStressProfile? = nil,
    canonicalGeometry: RouteGeometryCanonicalizer.CanonicalRouteGeometry? = nil,
    minimumTurnRadiusMeters: Double? = nil,
    applyTrafficToSimulation: Bool = false
  ) {
    stop()
    displayClock.stop()
    mailbox.reset()
    telemetryReport = nil
    staticWebETASeconds = totalDuration
    simulationElapsedSeconds = 0
    isPassengerCarMode = isPassengerCar
    self.applyTrafficToSimulation = applyTrafficToSimulation
    lastConfigureManeuvers = maneuvers
    lastConfigureTurnInstructions = turnInstructions
    lastConfigureEnvironmentalContext = environmentalContext
    lastConfigureVehicle = vehicle
    lastConfigureTotalDuration = totalDuration
    lastConfigureEnginePowerHP = enginePowerHP
    lastConfigureTomTomAPIKey = tomTomAPIKey
    lastConfigureMinimumTurnRadiusMeters = minimumTurnRadiusMeters
    lastRouteCoordinates = route
    currentKineticStress = nil
    bridgeRevision = 0
    displaySimulationTime = 0
    lastBridgeLatitude = nil
    lastBridgeLongitude = nil
    lastBridgeBearing = nil

    let gapFilledRoute = ElevationGapFiller.fillGaps(in: route)
    let canonical = canonicalGeometry ?? RouteGeometryCanonicalizer.process(gapFilledRoute)
    self.environmentalContext = environmentalContext
    densifiedRoute = canonical.simulationCoordinates
    segmentLengths = canonical.segmentLengths
    cumulativeLengths = canonical.cumulativeLengths
    totalRouteLength = canonical.totalLengthMeters
    arcLengthSampler = RouteArcLengthSampler(
      densifiedRoute: densifiedRoute,
      segmentLengths: segmentLengths,
      totalRouteLength: totalRouteLength
    )
    poseInterpolator = VehiclePoseInterpolator(sampler: arcLengthSampler)

    let path3D = densifiedRoute.map { coordinate in
      GeoCoordinate3D(
        latitude: coordinate.latitude,
        longitude: coordinate.longitude,
        elevationMeters: coordinate.elevationMeters
      )
    }
    let weightTonnes = vehicle.weight ?? (isPassengerCar ? 1.5 : 44.0)
    let telematics = PlateTelematicsPhysicsProfile.from(
      profile: vehicleSpecificationProfile,
      isPassengerCar: isPassengerCar,
      fallbackHP: enginePowerHP,
      fallbackMassKg: weightTonnes * 1000
    )
    self.kineticStressProfile = kineticStressProfile
      ?? KineticGradientAnalyzer.buildProfile(path: path3D, weightTons: telematics.weightTonnes)
    elevationProfile = ElevationProfile(coordinates: densifiedRoute)

    speedProfile = SimulationSpeedProfile(
      maneuvers: maneuvers,
      turnInstructions: turnInstructions,
      isPassengerCar: isPassengerCar,
      routeCoordinate: route.first.map {
        CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude)
      }
    )
    vehicleWeightTonnes = telematics.weightTonnes
    if let profile = vehicleSpecificationProfile {
      activeSpecificationProfile = profile
      vehicleLengthMeters = profile.lengthMeters
      vehicleWidthMeters = profile.widthMeters
    } else {
      activeSpecificationProfile = nil
      vehicleLengthMeters = vehicle.length ?? 12.0
      vehicleWidthMeters = vehicle.width ?? 2.55
    }
    self.enginePowerHP = telematics.powerHP
    dynamics = RouteDynamicsPhysics.SimulationVehicleDynamics.from(telematics: telematics)

    routingCoordinates = densifiedRoute.map {
      RoutingCoordinate(latitude: $0.latitude, longitude: $0.longitude)
    }

    let routeCoordinate = route.first.map {
      CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude)
    }
    let measurementSystem: RegionalMeasurementSystem
    if let routeCoordinate {
      measurementSystem = TelemetryUnitConverter.measurementSystem(for: routeCoordinate)
    } else {
      measurementSystem = .metric
    }
    let regionalLimits = VehicleSpeedLimits.limits(for: measurementSystem)
    let vehicleMaxSpeedKmh = isPassengerCar
      ? regionalLimits.carMajorRoadSpeedKmh
      : regionalLimits.hgvMajorRoadSpeedKmh
    let vehicleMaxSpeedMps = vehicleMaxSpeedKmh / 3.6
    let defaultSpeedFloorMps = regionalLimits.defaultSpeedKmh / 3.6

    if totalRouteLength > 0, totalDuration > 0 {
      let routeAverage = totalRouteLength / totalDuration
      cruiseSpeedMps = max(
        min(routeAverage, vehicleMaxSpeedMps),
        minimumCruiseSpeedMps
      )
    } else {
      cruiseSpeedMps = max(20, minimumCruiseSpeedMps)
    }

    playbackRevision = 0
    physicsAccumulator = 0
    pendingPhysicsSteps = 0

    if let first = densifiedRoute.first {
      currentCoordinate = CLLocationCoordinate2D(
        latitude: first.latitude,
        longitude: first.longitude
      )
      if densifiedRoute.count >= 2 {
        currentBearing = arcLengthSampler.bearingDegrees(at: 0)
      }
    } else {
      currentCoordinate = nil
    }

    let physicsConfig = SimulationPhysicsConfiguration(
      densifiedRoute: densifiedRoute,
      segmentLengths: segmentLengths,
      cumulativeLengths: cumulativeLengths,
      totalRouteLength: totalRouteLength,
      routingCoordinates: routingCoordinates,
      elevationProfile: elevationProfile,
      speedProfile: speedProfile,
      speedLimitResolver: BoxedRouteSpeedLimitResolver(
        SpineSpeedLimitResolver(
          cumulativeLengths: cumulativeLengths,
          legalSpeedLimitMps: canonical.legalSpeedLimitMps,
          fallbackResolver: speedProfile,
          vehicleCeilingKmh: vehicleMaxSpeedKmh
        )
      ),
      transitionProfile: isPassengerCar ? .standard : .hgv,
      vehicleMaxSpeedMps: vehicleMaxSpeedMps,
      defaultSpeedFloorMps: defaultSpeedFloorMps,
      kineticStressProfile: self.kineticStressProfile,
      dynamics: dynamics,
      environmentalContext: environmentalContext,
      vehicleWeightTonnes: vehicleWeightTonnes,
      enginePowerHP: self.enginePowerHP,
      cruiseSpeedMps: cruiseSpeedMps,
      isPassengerCarMode: isPassengerCarMode,
      activeSpecificationProfile: activeSpecificationProfile,
      staticWebETASeconds: staticWebETASeconds,
      minimumTurnRadiusMeters: minimumTurnRadiusMeters,
      turnInstructions: turnInstructions,
      applyTrafficToSimulation: applyTrafficToSimulation
    )
    configureTask = Task {
      await physicsActor.configure(physicsConfig)
    }
  }

  /// Runs a headless physics integration pass to predict kinetic route duration.
  public func estimatePhysicsDuration() async -> PhysicsRouteDurationResult? {
    await configureTask?.value
    guard let config = await physicsActor.exportConfiguration() else { return nil }
    return await PhysicsRouteDurationEstimator.estimate(
      configuration: config,
      tomTomAPIKey: lastConfigureTomTomAPIKey
    )
  }

  /// Runs a full pre-trip physics rehearsal and stores the predictive telemetry report.
  public func rehearseRoute() async -> PredictiveTelemetryReport? {
    await configureTask?.value
    guard let config = await physicsActor.exportConfiguration() else { return nil }
    let report = await RouteRehearsalService.rehearse(
      configuration: config,
      tomTomAPIKey: lastConfigureTomTomAPIKey
    )
    if let report {
      telemetryReport = report
    }
    return report
  }

  /// Configures the simulation from 2D map coordinates with optional parallel elevations.
  public func configure(
    route: [CLLocationCoordinate2D],
    elevations: [Double?] = [],
    environmentalContext: EnvironmentalContext = .dry,
    vehicle: VehicleProfile,
    totalDuration: TimeInterval,
    enginePowerHP: Double = RouteDynamicsPhysics.defaultEnginePowerHP,
    maneuvers: [ExternalManeuver] = [],
    turnInstructions: [TurnInstruction] = [],
    isPassengerCar: Bool = false,
    tomTomAPIKey: String? = nil,
    vehicleSpecificationProfile: VehicleSpecificationProfile? = nil,
    kineticStressProfile: KineticStressProfile? = nil
  ) {
    let coordinates = route.enumerated().map { index, coordinate in
      let elevation = elevations.indices.contains(index) ? elevations[index] : nil
      return Coordinate(
        latitude: coordinate.latitude,
        longitude: coordinate.longitude,
        elevationMeters: elevation
      )
    }
    configure(
      route: coordinates,
      environmentalContext: environmentalContext,
      vehicle: vehicle,
      totalDuration: totalDuration,
      enginePowerHP: enginePowerHP,
      maneuvers: maneuvers,
      turnInstructions: turnInstructions,
      isPassengerCar: isPassengerCar,
      tomTomAPIKey: tomTomAPIKey,
      vehicleSpecificationProfile: vehicleSpecificationProfile,
      kineticStressProfile: kineticStressProfile
    )
  }

  /// Replaces turn instructions after async lane enrichment without resetting playback.
  public func updateTurnInstructions(_ instructions: [TurnInstruction]) {
    lastConfigureTurnInstructions = instructions
  }

  /// Updates whether TomTom congestion caps steady-state cruise speed.
  public func updateApplyTrafficToSimulation(_ enabled: Bool) {
    applyTrafficToSimulation = enabled
    guard !lastRouteCoordinates.isEmpty else { return }
    configure(
      route: lastRouteCoordinates,
      environmentalContext: lastConfigureEnvironmentalContext,
      vehicle: lastConfigureVehicle,
      totalDuration: lastConfigureTotalDuration,
      enginePowerHP: lastConfigureEnginePowerHP,
      maneuvers: lastConfigureManeuvers,
      turnInstructions: lastConfigureTurnInstructions,
      isPassengerCar: isPassengerCarMode,
      tomTomAPIKey: lastConfigureTomTomAPIKey,
      vehicleSpecificationProfile: activeSpecificationProfile,
      minimumTurnRadiusMeters: lastConfigureMinimumTurnRadiusMeters,
      applyTrafficToSimulation: enabled
    )
  }

  /// Updates environmental context without resetting route playback position.
  public func updateEnvironmentalContext(_ context: EnvironmentalContext) {
    environmentalContext = context
    Task {
      await configureTask?.value
      await physicsActor.updateEnvironmentalContext(context)
    }
  }

  /// Updates the vehicle specification profile and rebuilds simulation physics when a route is active.
  public func configureVehicleSpecification(
    _ profile: VehicleSpecificationProfile,
    vehicle: VehicleProfile? = nil,
    minimumTurnRadiusMeters: Double? = nil
  ) async {
    activeSpecificationProfile = profile
    vehicleLengthMeters = profile.lengthMeters
    vehicleWidthMeters = profile.widthMeters
    dimensionRevision &+= 1
    isPassengerCarMode = profile.vehicleClass == .passengerCar
    if let vehicle {
      lastConfigureVehicle = vehicle
    }
    if let minimumTurnRadiusMeters {
      lastConfigureMinimumTurnRadiusMeters = minimumTurnRadiusMeters
    }

    guard !lastRouteCoordinates.isEmpty else {
      await configureTask?.value
      await physicsActor.configureVehicleProfile(profile)
      refreshLiveFootprint(lengthMeters: profile.lengthMeters, widthMeters: profile.widthMeters)
      return
    }

    let isPassengerCar = profile.vehicleClass == .passengerCar
    configure(
      route: lastRouteCoordinates,
      environmentalContext: lastConfigureEnvironmentalContext,
      vehicle: lastConfigureVehicle,
      totalDuration: lastConfigureTotalDuration,
      enginePowerHP: lastConfigureEnginePowerHP,
      maneuvers: lastConfigureManeuvers,
      turnInstructions: lastConfigureTurnInstructions,
      isPassengerCar: isPassengerCar,
      tomTomAPIKey: lastConfigureTomTomAPIKey,
      vehicleSpecificationProfile: profile,
      minimumTurnRadiusMeters: lastConfigureMinimumTurnRadiusMeters,
      applyTrafficToSimulation: applyTrafficToSimulation
    )
  }

  /// Current maximum absolute road grade along the configured route.
  public var maxRouteGradePercent: Double {
    elevationProfile.maxAbsoluteGradePercent
  }

  /// Toggles simulation playback.
  public func toggleSimulation() {
    if isRunning {
      stop()
    } else {
      start()
    }
  }

  /// Stops simulation and resets playback position.
  public func stop() {
    displayClock.stop()
    mailbox.reset()
    physicsAccumulator = 0
    pendingPhysicsSteps = 0
    physicsDrainInFlight = false
    displaySimulationTime = 0
    lastBridgeLatitude = nil
    lastBridgeLongitude = nil
    lastBridgeBearing = nil
    isRunning = false
    onSimulationStopped?()
    Task {
      await physicsActor.stop()
    }

    if let first = densifiedRoute.first {
      currentCoordinate = CLLocationCoordinate2D(
        latitude: first.latitude,
        longitude: first.longitude
      )
      if densifiedRoute.count >= 2 {
        currentBearing = arcLengthSampler.bearingDegrees(at: 0)
      }
    }
  }

  /// Updates live vehicle footprint dimensions and pushes to the map during active simulation.
  public func refreshLiveFootprint(lengthMeters: Double, widthMeters: Double) {
    vehicleLengthMeters = lengthMeters
    vehicleWidthMeters = widthMeters
    dimensionRevision &+= 1

    guard isRunning, let coordinate = currentCoordinate else { return }

    bridgeRevision &+= 1
    SimulationMapBridge.shared.push(
      makeSimulatedVehicleState(coordinate: coordinate)
    )
  }

  /// Advances one physics step with a fixed delta (unit tests only).
  public func simulateTick(deltaTime: Double) async {
    await configureTask?.value
    if let result = await physicsActor.simulateTick(
      deltaTime: deltaTime,
      simulationSpeedMultiplier: simulationSpeedMultiplier
    ) {
      handleSimulationCompleted(result)
    }
    applyUIStateFromMailbox(force: true)
    applyInterpolatedDisplay(at: ContinuousClock.now)
    if isRunning, let coordinate = currentCoordinate {
      bridgeRevision &+= 1
      SimulationMapBridge.shared.push(makeSimulatedVehicleState(coordinate: coordinate))
    }
  }

  private func start() {
    guard densifiedRoute.count >= 3 else { return }
    isRunning = true
    simulationElapsedSeconds = 0
    physicsAccumulator = 0
    pendingPhysicsSteps = 0
    displaySimulationTime = 0
    lastBridgeLatitude = nil
    lastBridgeLongitude = nil
    lastBridgeBearing = nil
    bridgeRevision = 0

    Task {
      await configureTask?.value
      await physicsActor.resetTelemetry()
      await physicsActor.start()
      if let onSimulationStarting {
        await onSimulationStarting()
      }
      displayClock.start { [weak self] tick in
        self?.renderDisplayFrame(tick)
      }
      onSimulationStarted?()
    }
  }

  private func renderDisplayFrame(_ tick: DisplayFrameTick) {
    guard isRunning else { return }

    let signpost = SimulationInstrumentation.beginDisplayFrame()
    defer { SimulationInstrumentation.endDisplayFrame(signpost) }

    displaySimulationTime += tick.deltaTime * simulationSpeedMultiplier

    physicsAccumulator += tick.deltaTime
    while physicsAccumulator >= physicsStepSeconds {
      physicsAccumulator -= physicsStepSeconds
      pendingPhysicsSteps += 1
    }
    schedulePhysicsDrain()

    applyUIStateFromMailbox(force: false)
    applyInterpolatedDisplay(at: ContinuousClock.now)
    onDisplayFrameTick?()

    if let coordinate = currentCoordinate, shouldPushBridgeUpdate(coordinate: coordinate, bearing: currentBearing) {
      bridgeRevision &+= 1
      lastBridgeLatitude = coordinate.latitude
      lastBridgeLongitude = coordinate.longitude
      lastBridgeBearing = currentBearing
    }
  }

  private func shouldPushBridgeUpdate(coordinate: CLLocationCoordinate2D, bearing: Double) -> Bool {
    guard let lastBridgeLatitude, let lastBridgeLongitude, let lastBridgeBearing else {
      return true
    }
    let latitudeDelta = abs(coordinate.latitude - lastBridgeLatitude)
    let longitudeDelta = abs(coordinate.longitude - lastBridgeLongitude)
    let bearingDelta = abs(bearing - lastBridgeBearing)
    return latitudeDelta > bridgeCoordinateDeltaThreshold
      || longitudeDelta > bridgeCoordinateDeltaThreshold
      || bearingDelta > bridgeBearingDeltaThreshold
  }

  private func schedulePhysicsDrain() {
    guard !physicsDrainInFlight, pendingPhysicsSteps > 0 else { return }
    physicsDrainInFlight = true
    let maxStepsPerDrain = simulationSpeedMultiplier <= 1.0 ? 1 : maxCatchUpStepsPerFrame
    let steps = min(pendingPhysicsSteps, maxStepsPerDrain)
    pendingPhysicsSteps -= steps

    Task {
      for _ in 0..<steps {
        if let result = await physicsActor.step(
          fixedDeltaTime: physicsStepSeconds,
          simulationSpeedMultiplier: simulationSpeedMultiplier
        ) {
          await MainActor.run {
            self.handleSimulationCompleted(result)
          }
          break
        }
      }
      await MainActor.run {
        self.applyUIStateFromMailbox(force: false)
        self.physicsDrainInFlight = false
        self.schedulePhysicsDrain()
      }
    }
  }

  private func applyUIStateFromMailbox(force: Bool) {
    guard let uiState = mailbox.readUI() else { return }

    simulationElapsedSeconds = uiState.simulationElapsedSeconds
    currentSpeedKmh = uiState.speedKmh
    activeLegalSpeedLimitKmh = uiState.activeLegalSpeedLimitKmh
    trafficAdjustedLimitKmh = uiState.trafficAdjustedLimitKmh
    activeSpeedLimitSource = uiState.speedLimitSource
    isBrakingWarning = uiState.isBrakingWarning
    isPausedForSignal = uiState.isPausedForSignal
    brakeFadeRisk = uiState.brakeFadeRisk
    topographyState = uiState.topographyState
    currentKineticStress = uiState.currentKineticStress

    if !uiState.isRunning, isRunning {
      isRunning = false
      displayClock.stop()
    }

    let now = ContinuousClock.now
    if force || shouldPublishUI(now: now) {
      lastPublishedUIInstant = now
      playbackRevision &+= 1
      onUIStatePublished?(uiState)
    }
  }

  private func shouldPublishUI(now: ContinuousClock.Instant) -> Bool {
    guard let lastPublishedUIInstant else { return true }
    let elapsed = Self.seconds(from: lastPublishedUIInstant.duration(to: now))
    return elapsed >= uiPublishMinIntervalSeconds
  }

  private func applyInterpolatedDisplay(at time: ContinuousClock.Instant) {
    guard let interpolator = poseInterpolator else { return }

    let snapshots = mailbox.readDisplay()?.poseSnapshots ?? []
    let fallbackArcLength = mailbox.readDisplay()?.arcLengthMeters ?? 0
    let fallbackBearing = mailbox.readDisplay()?.bearingDegrees ?? currentBearing

    let pose: InterpolatedVehiclePose
    if snapshots.count >= 2 {
      let earlier = snapshots[snapshots.count - 2]
      let later = snapshots[snapshots.count - 1]
      pose = interpolator.interpolate(
        from: earlier,
        to: later,
        at: time,
        displaySimulationTimeSeconds: displaySimulationTime
      )
    } else if let latest = snapshots.last {
      pose = interpolator.pose(from: latest)
    } else {
      let center = arcLengthSampler.coordinate(at: fallbackArcLength)
      pose = InterpolatedVehiclePose(
        coordinate: center,
        bearingDegrees: fallbackBearing,
        arcLengthMeters: fallbackArcLength
      )
    }

    currentCoordinate = CLLocationCoordinate2D(
      latitude: pose.coordinate.latitude,
      longitude: pose.coordinate.longitude
    )
    currentBearing = pose.bearingDegrees
    currentArcLengthStorage = pose.arcLengthMeters
  }

  private func handleSimulationCompleted(_ result: SimulationCompletionResult) {
    isRunning = false
    displayClock.stop()
    applyInterpolatedDisplay(at: ContinuousClock.now)
    telemetryReport = result.telemetryReport
    if let coordinate = currentCoordinate {
      SimulationMapBridge.shared.push(makeSimulatedVehicleState(coordinate: coordinate))
    }
  }

  private func resolvedFootprintDimensions() -> (length: Double, width: Double) {
    let length = activeSpecificationProfile?.lengthMeters ?? vehicleLengthMeters
    let width = activeSpecificationProfile?.widthMeters ?? vehicleWidthMeters
    return (length, width)
  }

  private func makeSimulatedVehicleState(
    coordinate: CLLocationCoordinate2D,
    renderMode: VehicleRenderMode = .polygon
  ) -> SimulatedVehicleState {
    let dimensions = resolvedFootprintDimensions()
    let footprint = VehicleGeometryCalculator.generateFootprint(
      rearAxle: coordinate,
      headingDegrees: currentBearing,
      lengthMeters: dimensions.length,
      widthMeters: dimensions.width
    )
    let parts = VehicleGeometryCalculator.generateFootprintParts(
      rearAxle: coordinate,
      headingDegrees: currentBearing,
      lengthMeters: dimensions.length,
      widthMeters: dimensions.width,
      isPassengerCar: isPassengerCarMode
    )
    return SimulatedVehicleState(
      latitude: coordinate.latitude,
      longitude: coordinate.longitude,
      bearing: currentBearing,
      visible: true,
      lengthMeters: dimensions.length,
      widthMeters: dimensions.width,
      playbackRevision: bridgeRevision,
      dimensionRevision: dimensionRevision,
      renderMode: renderMode,
      footprintCoordinates: footprint,
      footprintParts: parts,
      isPassengerCar: isPassengerCarMode,
      wheelbaseMeters: resolvedWheelbaseMeters()
    )
  }

  private func resolvedWheelbaseMeters() -> Double {
    if let profile = activeSpecificationProfile {
      return profile.wheelbaseMeters
    }
    return isPassengerCarMode ? 2.7 : 6.5
  }

  private func buildCumulativeLengths(from segments: [Double]) -> [Double] {
    var cumulative: [Double] = [0]
    for length in segments {
      cumulative.append(cumulative.last! + length)
    }
    return cumulative
  }

  private static func seconds(from duration: Duration) -> Double {
    let components = duration.components
    return Double(components.seconds)
      + Double(components.attoseconds) / 1_000_000_000_000_000_000
  }

  private func densifyCoordinates(_ coordinates: [Coordinate], stepMeters: Double) -> [Coordinate] {
    guard coordinates.count >= 2 else { return coordinates }

    var result: [Coordinate] = [coordinates[0]]
    for index in 0..<(coordinates.count - 1) {
      let from = coordinates[index]
      let to = coordinates[index + 1]
      let distance = segmentDistance(from, to)
      let steps = max(1, Int(distance / stepMeters))
      for step in 1...steps {
        let t = Double(step) / Double(steps)
        let elevation: Double?
        if let fromElevation = from.elevationMeters, let toElevation = to.elevationMeters {
          elevation = fromElevation + (toElevation - fromElevation) * t
        } else {
          elevation = from.elevationMeters ?? to.elevationMeters
        }
        result.append(Coordinate(
          latitude: from.latitude + (to.latitude - from.latitude) * t,
          longitude: from.longitude + (to.longitude - from.longitude) * t,
          elevationMeters: elevation
        ))
      }
    }
    return result
  }

  private func segmentDistance(_ a: Coordinate, _ b: Coordinate) -> Double {
    let earthRadius = 6_371_000.0
    let lat1 = a.latitude * .pi / 180
    let lat2 = b.latitude * .pi / 180
    let deltaLat = (b.latitude - a.latitude) * .pi / 180
    let deltaLon = (b.longitude - a.longitude) * .pi / 180
    let sinDLat = sin(deltaLat / 2)
    let sinDLon = sin(deltaLon / 2)
    let h = sinDLat * sinDLat + cos(lat1) * cos(lat2) * sinDLon * sinDLon
    return 2 * earthRadius * atan2(sqrt(h), sqrt(max(0, 1 - h)))
  }

  private func bearingBetween(_ from: Coordinate, _ to: Coordinate) -> Double {
    let lat1 = from.latitude * .pi / 180
    let lat2 = to.latitude * .pi / 180
    let dLon = (to.longitude - from.longitude) * .pi / 180
    let y = sin(dLon) * cos(lat2)
    let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
    let bearing = atan2(y, x) * 180 / .pi
    return normalizeDegrees(bearing)
  }

  private func normalizeDegrees(_ degrees: Double) -> Double {
    var value = degrees.truncatingRemainder(dividingBy: 360)
    if value < 0 { value += 360 }
    return value
  }
}
