import Contracts
import CostModel
import Testing

@Test func feasibleDefaultVehicle() {
    let model = CostModel()
    let edge = Edge(from: "A", to: "B", distance: 100, speed: 50)
    #expect(model.isFeasible(edge: edge, vehicle: .default))
}

@Test func infeasibleHeight() {
    let model = CostModel()
    let edge = Edge(from: "A", to: "B", distance: 100, speed: 50, maxHeight: 3.0)
    let vehicle = VehicleProfile(height: 4.0)
    #expect(!model.isFeasible(edge: edge, vehicle: vehicle))
}

@Test func fastestModeUsesTime() {
    let model = CostModel()
    let edge = Edge(from: "A", to: "B", distance: 1000, speed: 50)
    let cost = model.computeCost(edge: edge, prefs: PreferenceProfile(optimizationMode: .fastest))
    #expect(cost > 70)
    #expect(cost < 75)
}

@Test func shortestModeUsesDistance() {
    let model = CostModel()
    let edge = Edge(from: "A", to: "B", distance: 1000, speed: 50)
    let cost = model.computeCost(edge: edge, prefs: PreferenceProfile(optimizationMode: .shortest))
    #expect(cost == 1000)
}

@Test func hurryModeCameraPenalty() {
    let model = CostModel()
    let edge = Edge(from: "A", to: "B", distance: 1000, speed: 80, hasCamera: true)
    let normal = model.computeCost(edge: edge, prefs: PreferenceProfile(optimizationMode: .fastest, hurryMode: false))
    let hurry = model.computeCost(edge: edge, prefs: PreferenceProfile(optimizationMode: .fastest, hurryMode: true))
    #expect(hurry > normal)
}

@Test func hurryModeHighwayBias() {
    let model = CostModel()
    let highway = Edge(from: "A", to: "B", distance: 1000, speed: 100, roadType: .motorway)
    let normal = model.computeCost(edge: highway, prefs: PreferenceProfile(optimizationMode: .fastest, hurryMode: false))
    let hurry = model.computeCost(edge: highway, prefs: PreferenceProfile(optimizationMode: .fastest, hurryMode: true))
    #expect(hurry < normal)
}

@Test func avoidTollPenalty() {
    let model = CostModel()
    let edge = Edge(from: "A", to: "B", distance: 100, speed: 50, isToll: true)
    let cost = model.computeCost(edge: edge, prefs: PreferenceProfile(avoidTolls: true))
    #expect(cost >= CostConstants.tollPenalty)
}

@Test func zeroSpeedDefaultsToFifty() {
    let time = CostModel.travelTime(for: Edge(from: "A", to: "B", distance: 1000, speed: 0))
    let expectedTime = 1000.0 / (50.0 * 1000 / 3600)
    #expect(abs(time - expectedTime) < 0.01)
}

@Test func simplestTurnPenalty() {
    let model = CostModel()
    let edge = Edge(from: "A", to: "B", distance: 1000, speed: 50, roadType: .secondary)
    let cost = model.computeCost(edge: edge, prefs: PreferenceProfile(optimizationMode: .simplest), previousRoadType: .primary)
    let baseCost = model.computeCost(edge: edge, prefs: PreferenceProfile(optimizationMode: .simplest), previousRoadType: .secondary)
    #expect(cost - baseCost == CostConstants.turnPenalty)
}

@Test func leastStressfulCameraPenalty() {
    let model = CostModel()
    let edge = Edge(from: "A", to: "B", distance: 1000, speed: 50, hasCamera: true)
    let cost = model.computeCost(edge: edge, prefs: PreferenceProfile(optimizationMode: .leastStressful))
    let noCamera = model.computeCost(edge: edge, prefs: PreferenceProfile(optimizationMode: .fastest))
    #expect(cost - noCamera >= CostConstants.cameraPenalty)
}

@Test func routingPreferencesBundle() {
    let prefs = RoutingPreferences(
        optimizationMode: .fastest,
        avoidTolls: true,
        hurryMode: true,
        isHGVMode: true,
        avoidResidential: true,
        vehicle: VehicleProfile(height: 2.5),
        algorithm: .aStar
    )
    #expect(prefs.preferenceProfile.avoidTolls)
    #expect(prefs.preferenceProfile.hurryMode)
    #expect(prefs.preferenceProfile.isHGVMode)
    #expect(prefs.preferenceProfile.avoidResidential)
    #expect(prefs.vehicle.height == 2.5)
    #expect(prefs.algorithm == .aStar)
}

@Test func hgvHeightBlockedOnLowBridge() {
    let model = CostModel()
    let edge = Edge(from: "A", to: "B", distance: 100, speed: 50, maxHeight: 3.5)
    let vehicle = VehicleProfile(height: 4.0)
    let prefs = PreferenceProfile(isHGVMode: true)
    #expect(!model.isFeasible(edge: edge, vehicle: vehicle, prefs: prefs))
}

@Test func hgvAvoidsResidential() {
    let model = CostModel()
    let residential = Edge(from: "A", to: "B", distance: 100, speed: 30, roadType: .residential)
    let trunk = Edge(from: "A", to: "C", distance: 200, speed: 60, roadType: .trunk)
    let vehicle = VehicleProfile(height: 4.0)
    let prefs = PreferenceProfile(isHGVMode: true, avoidResidential: true)
    #expect(!model.isFeasible(edge: residential, vehicle: vehicle, prefs: prefs))
    #expect(model.isFeasible(edge: trunk, vehicle: vehicle, prefs: prefs))
}

@Test func hgvRestrictedEdgeBlocked() {
    let model = CostModel()
    let edge = Edge(from: "A", to: "B", distance: 100, speed: 50, hgvRestricted: true)
    let vehicle = VehicleProfile(height: 4.0)
    let prefs = PreferenceProfile(isHGVMode: true)
    #expect(!model.isFeasible(edge: edge, vehicle: vehicle, prefs: prefs))
}

@Test func turningRadiusRightAngleCorner() {
    let p0 = Coordinate(latitude: 51.5000, longitude: -0.1000)
    let p1 = Coordinate(latitude: 51.5000, longitude: -0.0990)
    let p2 = Coordinate(latitude: 51.4990, longitude: -0.0990)
    let radius = RouteDynamicsPhysics.turningRadiusMeters(p0: p0, p1: p1, p2: p2)
    #expect(radius > 50)
    #expect(radius < 500)
}

@Test func weightScaledDeceleration() {
    let light = RouteDynamicsPhysics.decelerationMps2(weightTonnes: 7.5)
    let laden = RouteDynamicsPhysics.decelerationMps2(weightTonnes: 44)
    #expect(laden < light)
    #expect(abs(laden - 2.0) < 0.3)
}

@Test func stoppingDistanceIncreasesWithSpeed() {
    let slow = RouteDynamicsPhysics.stoppingDistanceMeters(speedMps: 10, deceleration: 3.5)
    let fast = RouteDynamicsPhysics.stoppingDistanceMeters(speedMps: 20, deceleration: 3.5)
    #expect(fast > slow)
    #expect(abs(slow - (100.0 / 7.0)) < 0.5)
}

@Test func maxCurveSpeedScalesWithRadius() {
    let tight = RouteDynamicsPhysics.maxCurveSpeedMps(radiusMeters: 20)
    let wide = RouteDynamicsPhysics.maxCurveSpeedMps(radiusMeters: 200)
    #expect(wide > tight)
}
