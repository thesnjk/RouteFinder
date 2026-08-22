/// Classification of road segments used for cost weighting and turn instructions.
public enum RoadType: String, Codable, Sendable, Hashable, CaseIterable {
    case motorway
    case trunk
    case primary
    case secondary
    case tertiary
    case residential
    case service
    case unclassified
    case ferry
    case unknown
}
