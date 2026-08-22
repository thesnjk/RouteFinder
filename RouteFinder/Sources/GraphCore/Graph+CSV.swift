import Contracts
import Foundation

extension Graph {
    /// Loads a graph from CSV files.
    ///
    /// Node CSV format: `id,latitude,longitude,name`
    /// Edge CSV format: `from,to,distance,speed,road_type,is_toll,is_ferry,is_tunnel,max_height,max_weight,max_width,max_length,has_camera,is_one_way,hgv_restricted,road_name,camera_type,max_axle_weight,hazmat_restricted,lez_restricted,min_turn_radius`
    public static func loadFromCSV(nodesPath: String, edgesPath: String) async throws -> Graph {
        let nodeLines = try await CSVParser.readLines(from: nodesPath)
        let edgeLines = try await CSVParser.readLines(from: edgesPath)

        let graph = Graph(nodeCapacity: nodeLines.count, edgeCapacity: edgeLines.count)

        for (index, line) in nodeLines.enumerated() {
            guard let fields = CSVParser.splitLine(line) else { continue }
            guard fields.count >= 3 else {
                throw CSVParseError.invalidFormat(line: index + 1, reason: "Expected at least 3 node fields")
            }

            guard let lat = CSVParser.parseDouble(fields[1]),
                  let lon = CSVParser.parseDouble(fields[2]) else {
                throw CSVParseError.invalidFormat(line: index + 1, reason: "Invalid latitude/longitude")
            }

            let name: String? = fields.count > 3 && !fields[3].trimmingCharacters(in: .whitespaces).isEmpty
                ? String(fields[3])
                : nil

            graph.addNode(Node(id: String(fields[0]), latitude: lat, longitude: lon, name: name))
        }

        for (index, line) in edgeLines.enumerated() {
            guard let fields = CSVParser.splitLine(line) else { continue }
            guard fields.count >= 4 else {
                throw CSVParseError.invalidFormat(line: index + 1, reason: "Expected at least 4 edge fields")
            }

            guard let distance = CSVParser.parseDouble(fields[2]),
                  let speed = CSVParser.parseDouble(fields[3]) else {
                throw CSVParseError.invalidFormat(line: index + 1, reason: "Invalid distance/speed")
            }

            let roadType = fields.count > 4 ? CSVParser.parseRoadType(fields[4]) : .unknown
            let isToll = fields.count > 5 ? CSVParser.parseBool(fields[5]) : false
            let isFerry = fields.count > 6 ? CSVParser.parseBool(fields[6]) : false
            let isTunnel = fields.count > 7 ? CSVParser.parseBool(fields[7]) : false
            let maxHeight = fields.count > 8 ? CSVParser.parseOptionalDouble(fields[8]) : nil
            let maxWeight = fields.count > 9 ? CSVParser.parseOptionalDouble(fields[9]) : nil
            let maxWidth = fields.count > 10 ? CSVParser.parseOptionalDouble(fields[10]) : nil
            let maxLength = fields.count > 11 ? CSVParser.parseOptionalDouble(fields[11]) : nil
            let hasCamera = fields.count > 12 ? CSVParser.parseBool(fields[12]) : false
            let isOneWay = fields.count > 13 ? CSVParser.parseBool(fields[13]) : false

            let hgvRestricted: Bool
            let roadName: String?
            let cameraType: CameraType?
            let maxAxleWeight: Double?
            let hazmatRestricted: Bool
            let lezRestricted: Bool
            let minTurnRadius: Double?

            if fields.count > 15 {
                hgvRestricted = CSVParser.parseBool(fields[14])
                roadName = fields[15].trimmingCharacters(in: .whitespaces).isEmpty ? nil : String(fields[15])
                cameraType = fields.count > 16 ? CSVParser.parseCameraType(fields[16]) : nil
                maxAxleWeight = fields.count > 17 ? CSVParser.parseOptionalDouble(fields[17]) : nil
                hazmatRestricted = fields.count > 18 ? CSVParser.parseBool(fields[18]) : false
                lezRestricted = fields.count > 19 ? CSVParser.parseBool(fields[19]) : false
                minTurnRadius = fields.count > 20 ? CSVParser.parseOptionalDouble(fields[20]) : nil
            } else if fields.count > 14 {
                hgvRestricted = false
                roadName = fields[14].trimmingCharacters(in: .whitespaces).isEmpty ? nil : String(fields[14])
                cameraType = nil
                maxAxleWeight = nil
                hazmatRestricted = false
                lezRestricted = false
                minTurnRadius = nil
            } else {
                hgvRestricted = false
                roadName = nil
                cameraType = nil
                maxAxleWeight = nil
                hazmatRestricted = false
                lezRestricted = false
                minTurnRadius = nil
            }

            graph.addEdge(Edge(
                from: String(fields[0]),
                to: String(fields[1]),
                distance: distance,
                speed: speed,
                roadType: roadType,
                isToll: isToll,
                isFerry: isFerry,
                isTunnel: isTunnel,
                maxHeight: maxHeight,
                maxWeight: maxWeight,
                maxWidth: maxWidth,
                maxLength: maxLength,
                hasCamera: hasCamera,
                cameraType: cameraType,
                isOneWay: isOneWay,
                hgvRestricted: hgvRestricted,
                maxAxleWeight: maxAxleWeight,
                hazmatRestricted: hazmatRestricted,
                lezRestricted: lezRestricted,
                minTurnRadius: minTurnRadius,
                roadName: roadName
            ))
        }

        graph.buildSpatialIndex()
        return graph
    }
}
