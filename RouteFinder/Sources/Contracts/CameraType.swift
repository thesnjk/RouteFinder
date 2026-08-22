/// Type of speed or traffic enforcement camera on a road segment.
public enum CameraType: String, Codable, Sendable, Hashable, CaseIterable {
    case fixed
    case averageSpeedZone
    case redLight
    case mobile
}
