import Contracts
import GraphCore
import Foundation

/// GeoJSON hazard features extracted from the loaded routing graph.
public struct HazardOverlayModel: Sendable {
    /// GeoJSON FeatureCollection JSON string for MapLibre.
    public let geoJSON: String

    /// Creates a hazard overlay from raw GeoJSON.
    public init(geoJSON: String) {
        self.geoJSON = geoJSON
    }

    /// Builds hazard features for speed cameras and enforcement zones on the graph.
    public static func build(from graph: any GraphProtocol) -> HazardOverlayModel {
        var features: [String] = []
        var seen = Set<String>()

        for nodeID in allNodeIDs(from: graph) {
            guard let node = graph.node(id: nodeID) else { continue }
            for edge in graph.neighbors(of: nodeID) {
                guard edge.hasCamera || edge.cameraType != nil else { continue }
                let key = "\(edge.from)-\(edge.to)-\(edge.cameraType?.rawValue ?? "camera")"
                guard seen.insert(key).inserted else { continue }

                guard let toNode = graph.node(id: edge.to) else { continue }
                let midLat = (node.latitude + toNode.latitude) / 2
                let midLon = (node.longitude + toNode.longitude) / 2
                let hazardType = edge.cameraType?.rawValue ?? "fixed"
                let color = hazardColor(for: edge.cameraType)
                features.append("""
                {"type":"Feature","geometry":{"type":"Point","coordinates":[\(midLon),\(midLat)]},"properties":{"hazardType":"\(hazardType)","color":"\(color)","roadName":"\(escapeJSON(edge.roadName ?? ""))"}}
                """)
            }
        }

        let collection = """
        {"type":"FeatureCollection","features":[\(features.joined(separator: ","))]}
        """
        return HazardOverlayModel(geoJSON: collection)
    }

    private static func allNodeIDs(from graph: any GraphProtocol) -> [String] {
        if let tiled = graph as? TiledGraph {
            return tiled.allNodeIDs
        }
        if let concrete = graph as? Graph {
            return concrete.nodeIDs
        }
        return []
    }

    private static func hazardColor(for type: CameraType?) -> String {
        switch type {
        case .averageSpeedZone: return "#f97316"
        case .redLight: return "#ef4444"
        case .mobile: return "#eab308"
        case .fixed, .none: return "#dc2626"
        }
    }

    private static func escapeJSON(_ value: String) -> String {
        value.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }
}
