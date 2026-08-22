import Contracts
import Foundation

/// Default cost model implementing feasibility checks and preference-based costing.
public struct CostModel: CostModelProtocol {
    public init() {}

    /// Returns whether a vehicle can traverse the given edge.
    public func isFeasible(edge: Edge, vehicle: VehicleProfile, prefs: PreferenceProfile) -> Bool {
        if prefs.isHGVMode && edge.hgvRestricted {
            return false
        }
        if prefs.isHGVMode && prefs.avoidResidential {
            switch edge.roadType {
            case .residential, .service:
                return false
            default:
                break
            }
        }
        if let maxHeight = edge.maxHeight, let height = vehicle.height, height > maxHeight {
            return false
        }
        if let maxWeight = edge.maxWeight, let weight = vehicle.weight, weight > maxWeight {
            return false
        }
        if let maxWidth = edge.maxWidth, let width = vehicle.width, width > maxWidth {
            return false
        }
        if let maxLength = edge.maxLength, let length = vehicle.length, length > maxLength {
            return false
        }
        if let maxAxle = edge.maxAxleWeight, let axle = vehicle.axleWeight, axle > maxAxle {
            return false
        }
        if prefs.avoidHazmatRestricted,
           edge.hazmatRestricted,
           let hazmat = vehicle.hazmatClass,
           hazmat != .none {
            return false
        }
        if prefs.isHGVMode && edge.lezRestricted, vehicle.emissionClass == nil {
            return false
        }
        if prefs.enforceTurnRadius,
           let minRadius = edge.minTurnRadius,
           let vehicleRadius = vehicle.turningRadius,
           vehicleRadius > minRadius {
            return false
        }
        if let clearance = vehicle.groundClearance, clearance < 0.1, edge.isTunnel {
            return false
        }
        return true
    }

    /// Computes traversal cost based on optimization mode and preferences.
    public func computeCost(edge: Edge, prefs: PreferenceProfile) -> Double {
        computeCost(edge: edge, prefs: prefs, previousRoadType: nil)
    }

    /// Computes traversal cost with optional turn context for simplest mode.
    public func computeCost(edge: Edge, prefs: PreferenceProfile, previousRoadType: RoadType?) -> Double {
        var cost = baseCost(edge: edge, mode: prefs.optimizationMode, hurryMode: prefs.hurryMode)
        cost += avoidPenalties(edge: edge, prefs: prefs)
        cost += cameraPenalty(edge: edge, prefs: prefs)
        cost += highwayBias(edge: edge, baseTime: travelTime(for: edge), hurryMode: prefs.hurryMode)

        if prefs.optimizationMode == .simplest,
           let previous = previousRoadType,
           previous != edge.roadType {
            cost += CostConstants.turnPenalty
        }

        if prefs.optimizationMode == .leastStressful, !prefs.hurryMode {
            if edge.roadType == .motorway {
                cost += CostConstants.motorwayBonus
            }
        }

        return cost
    }

    /// Effective speed in m/s, defaulting zero speeds to 50 km/h.
    public static func effectiveSpeedMetersPerSecond(for edge: Edge) -> Double {
        let speedKmh = edge.speed > 0 ? edge.speed : CostConstants.defaultSpeedKmh
        return speedKmh * 1000 / 3600
    }

    /// Travel time in seconds for an edge.
    public static func travelTime(for edge: Edge) -> TimeInterval {
        edge.distance / effectiveSpeedMetersPerSecond(for: edge)
    }

    private func travelTime(for edge: Edge) -> TimeInterval {
        Self.travelTime(for: edge)
    }

    private func baseCost(edge: Edge, mode: OptimizationMode, hurryMode: Bool) -> Double {
        switch mode {
        case .fastest, .simplest, .leastStressful:
            return travelTime(for: edge)
        case .shortest:
            return edge.distance
        }
    }

    private func avoidPenalties(edge: Edge, prefs: PreferenceProfile) -> Double {
        var penalty = 0.0
        if prefs.avoidTolls && edge.isToll { penalty += CostConstants.tollPenalty }
        if prefs.avoidFerries && edge.isFerry { penalty += CostConstants.ferryPenalty }
        if prefs.avoidTunnels && edge.isTunnel { penalty += CostConstants.tunnelPenalty }
        return penalty
    }

    private func cameraPenalty(edge: Edge, prefs: PreferenceProfile) -> Double {
        guard edge.hasCamera || edge.cameraType != nil else { return 0 }

        if prefs.avoidCameras {
            let multiplier = prefs.isHGVMode ? 1.5 : 1.0
            return CostConstants.cameraPenalty * multiplier
        }

        if prefs.hurryMode {
            let speedKmh = edge.speed > 0 ? edge.speed : CostConstants.defaultSpeedKmh
            let exponent = CostConstants.hurryCameraExponentK * speedKmh / CostConstants.hurryCameraSpeedRefKmh
            let multiplier = min(exp(exponent), CostConstants.hurryCameraPenaltyCap)
            return CostConstants.cameraPenalty * multiplier
        }

        if prefs.optimizationMode == .leastStressful {
            return CostConstants.cameraPenalty
        }

        return 0
    }

    private func highwayBias(edge: Edge, baseTime: TimeInterval, hurryMode: Bool) -> Double {
        guard hurryMode else { return 0 }
        let speedKmh = edge.speed > 0 ? edge.speed : CostConstants.defaultSpeedKmh
        guard speedKmh >= CostConstants.hurryHighwayMinSpeedKmh else { return 0 }

        let speedRatio = min(speedKmh / CostConstants.heuristicMaxSpeedKmh, 1.0)
        return -baseTime * CostConstants.hurryHighwaySpeedBonus * speedRatio
    }
}
