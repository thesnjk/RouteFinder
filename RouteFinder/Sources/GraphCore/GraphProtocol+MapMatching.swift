import Contracts
import Foundation

extension GraphProtocol {
    /// Default map matching uses nearest-node snap only.
    public func matchToRoad(to coordinate: Coordinate, maxDistanceMeters: Double) -> MapMatchResult? {
        guard let node = findNearestNode(to: coordinate) else { return nil }
        let snapped = Coordinate(latitude: node.latitude, longitude: node.longitude)
        let distance = Haversine.distance(from: coordinate, to: snapped)
        guard distance <= maxDistanceMeters else { return nil }
        return MapMatchResult(
            nodeID: node.id,
            snappedCoordinate: snapped,
            snapDistanceMeters: distance,
            roadName: node.name
        )
    }
}
