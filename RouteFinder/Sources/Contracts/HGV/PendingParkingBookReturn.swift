import Foundation

/// Partner used for a parking book redirect (TRAVIS / SNAP).
public enum ParkingBookPartner: String, Sendable, Hashable, Codable, CaseIterable {
    case travis
    case snap

    /// Short driver-facing label.
    public var displayName: String {
        switch self {
        case .travis: return "TRAVIS"
        case .snap: return "SNAP"
        }
    }
}

/// Stashed when the driver opens a partner book link so nav can resume after the browser bounce.
///
/// Partners do not expose a documented return URL — this is app-side resume chrome only.
public struct PendingParkingBookReturn: Sendable, Hashable, Codable, Equatable, Identifiable {
    /// Maximum age before the pending return is ignored.
    public static let freshnessLimitSeconds: TimeInterval = 30 * 60

    public let id: String
    public let label: String
    public let latitude: Double
    public let longitude: Double
    public let partner: ParkingBookPartner
    public let openedAt: Date
    public let tier: ParkingAvailabilityTier?

    public init(
        id: String,
        label: String,
        latitude: Double,
        longitude: Double,
        partner: ParkingBookPartner,
        openedAt: Date = Date(),
        tier: ParkingAvailabilityTier? = nil
    ) {
        self.id = id
        self.label = label
        self.latitude = latitude
        self.longitude = longitude
        self.partner = partner
        self.openedAt = openedAt
        self.tier = tier
    }

    /// Whether the pending return is still fresh enough to show a resume banner.
    public func isFresh(asOf now: Date = Date()) -> Bool {
        now.timeIntervalSince(openedAt) < Self.freshnessLimitSeconds
    }

    /// Resume banner primary copy.
    public var resumeMessage: String {
        "Back from \(partner.displayName) — continue to \(label)?"
    }
}

/// Pure helpers for tier-aware parking book CTA copy (CoPilot-style emphasis).
public enum ParkingBookCTACopy: Sendable {
    /// Optional caution / guidance under the Book links.
    public static func caption(for tier: ParkingAvailabilityTier?) -> String? {
        guard let tier else { return nil }
        switch tier {
        case .ample:
            return nil
        case .limited:
            return "May fill soon — book early if you need a bay."
        case .full:
            return "Site may be full — book anyway or pick another stop."
        }
    }

    /// Whether TRAVIS should be visually emphasized over SNAP.
    public static func emphasizesTravis(for tier: ParkingAvailabilityTier?) -> Bool {
        tier == .ample
    }

    /// Whether both Book actions should use a secondary / outlined style (full sites).
    public static func usesSecondaryBookStyle(for tier: ParkingAvailabilityTier?) -> Bool {
        tier == .full
    }
}
