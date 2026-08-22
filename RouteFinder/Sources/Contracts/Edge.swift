/// A directed road segment connecting two nodes.
public struct Edge: Sendable, Hashable, Encodable {
    /// Source node identifier.
    public let from: String
    /// Destination node identifier.
    public let to: String
    /// Segment length in meters.
    public let distance: Double
    /// Speed limit in km/h; zero values are treated as 50 km/h by the cost model.
    public let speed: Double
    /// Road classification.
    public let roadType: RoadType
    /// Whether this segment is a toll road.
    public let isToll: Bool
    /// Whether this segment uses a ferry.
    public let isFerry: Bool
    /// Whether this segment passes through a tunnel.
    public let isTunnel: Bool
    /// Maximum vehicle height in meters, if restricted.
    public let maxHeight: Double?
    /// Maximum vehicle weight in tonnes, if restricted.
    public let maxWeight: Double?
    /// Maximum vehicle width in meters, if restricted.
    public let maxWidth: Double?
    /// Maximum vehicle length in meters, if restricted.
    public let maxLength: Double?
    /// Whether a speed camera is present on this segment.
    public let hasCamera: Bool
    /// Specific camera enforcement type, when known.
    public let cameraType: CameraType?
    /// Whether traffic flows in one direction only.
    public let isOneWay: Bool
    /// Whether HGV/truck access is restricted on this segment.
    public let hgvRestricted: Bool
    /// Maximum axle weight in tonnes, if restricted.
    public let maxAxleWeight: Double?
    /// Whether hazmat cargo is restricted on this segment.
    public let hazmatRestricted: Bool
    /// Whether the segment lies in a low-emission zone.
    public let lezRestricted: Bool
    /// Minimum turn radius in meters required to traverse adjacent geometry.
    public let minTurnRadius: Double?
    /// Optional road name for turn-by-turn instructions.
    public let roadName: String?

    /// Creates a road edge with the given attributes.
    public init(
        from: String,
        to: String,
        distance: Double,
        speed: Double,
        roadType: RoadType = .unknown,
        isToll: Bool = false,
        isFerry: Bool = false,
        isTunnel: Bool = false,
        maxHeight: Double? = nil,
        maxWeight: Double? = nil,
        maxWidth: Double? = nil,
        maxLength: Double? = nil,
        hasCamera: Bool = false,
        cameraType: CameraType? = nil,
        isOneWay: Bool = false,
        hgvRestricted: Bool = false,
        maxAxleWeight: Double? = nil,
        hazmatRestricted: Bool = false,
        lezRestricted: Bool = false,
        minTurnRadius: Double? = nil,
        roadName: String? = nil
    ) {
        self.from = from
        self.to = to
        self.distance = distance
        self.speed = speed
        self.roadType = roadType
        self.isToll = isToll
        self.isFerry = isFerry
        self.isTunnel = isTunnel
        self.maxHeight = maxHeight
        self.maxWeight = maxWeight
        self.maxWidth = maxWidth
        self.maxLength = maxLength
        self.hasCamera = hasCamera
        self.cameraType = cameraType
        self.isOneWay = isOneWay
        self.hgvRestricted = hgvRestricted
        self.maxAxleWeight = maxAxleWeight
        self.hazmatRestricted = hazmatRestricted
        self.lezRestricted = lezRestricted
        self.minTurnRadius = minTurnRadius
        self.roadName = roadName
    }

    enum CodingKeys: String, CodingKey {
        case from, to, distance, speed, roadType
        case isToll, isFerry, isTunnel
        case maxHeight, maxWeight, maxWidth, maxLength
        case hasCamera, cameraType, isOneWay, hgvRestricted
        case maxAxleWeight, hazmatRestricted, lezRestricted, minTurnRadius, roadName
    }
}

extension Edge: Decodable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        from = try container.decode(String.self, forKey: .from)
        to = try container.decode(String.self, forKey: .to)
        distance = try container.decodeIfPresent(Double.self, forKey: .distance) ?? 0
        speed = try container.decodeIfPresent(Double.self, forKey: .speed) ?? 0

        if let rawRoadType = try container.decodeIfPresent(String.self, forKey: .roadType) {
            roadType = RoadType(rawValue: rawRoadType) ?? .unknown
        } else {
            roadType = .unknown
        }

        isToll = container.decodeBool(forKey: .isToll)
        isFerry = container.decodeBool(forKey: .isFerry)
        isTunnel = container.decodeBool(forKey: .isTunnel)
        maxHeight = try container.decodeIfPresent(Double.self, forKey: .maxHeight)
        maxWeight = try container.decodeIfPresent(Double.self, forKey: .maxWeight)
        maxWidth = try container.decodeIfPresent(Double.self, forKey: .maxWidth)
        maxLength = try container.decodeIfPresent(Double.self, forKey: .maxLength)
        hasCamera = container.decodeBool(forKey: .hasCamera)
        cameraType = try container.decodeIfPresent(CameraType.self, forKey: .cameraType)
        isOneWay = container.decodeBool(forKey: .isOneWay)
        hgvRestricted = container.decodeBool(forKey: .hgvRestricted)
        maxAxleWeight = try container.decodeIfPresent(Double.self, forKey: .maxAxleWeight)
        hazmatRestricted = container.decodeBool(forKey: .hazmatRestricted)
        lezRestricted = container.decodeBool(forKey: .lezRestricted)
        minTurnRadius = try container.decodeIfPresent(Double.self, forKey: .minTurnRadius)
        roadName = try container.decodeIfPresent(String.self, forKey: .roadName)
    }
}

private extension KeyedDecodingContainer where K: CodingKey {
    func decodeBool(forKey key: K) -> Bool {
        (try? decodeIfPresent(Bool.self, forKey: key)) ?? false
    }
}
