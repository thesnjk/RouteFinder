import Foundation

/// UK fleet fuel card networks the driver can select for ahead-of-route matching.
public enum FuelCardProvider: String, Sendable, Hashable, Codable, CaseIterable, Identifiable {
    case none
    case keyfuels
    case ukFuels
    case allStar
    case esso
    case bp
    case other

    public var id: String { rawValue }

    /// Human-readable label for settings and banners.
    public var displayName: String {
        switch self {
        case .none: "None"
        case .keyfuels: "Keyfuels"
        case .ukFuels: "UK Fuels"
        case .allStar: "AllStar"
        case .esso: "Esso"
        case .bp: "BP"
        case .other: "Other"
        }
    }
}

/// Matches truck fuel POIs to the driver's selected fuel card network via name/brand substrings.
public enum FuelCardMatcher: Sendable {
    /// Returns whether the POI likely accepts the selected fuel card.
    public static func accepts(provider: FuelCardProvider, poi: TruckPoi) -> Bool {
        guard provider != .none else { return false }
        guard poi.kind == .highFlowDiesel else { return false }
        let haystack = searchableText(for: poi)
        guard !haystack.isEmpty else { return provider == .other ? false : false }
        return needles(for: provider).contains { haystack.contains($0) }
    }

    /// Banner copy when at least one ahead POI matches the selected provider.
    public static func aheadBannerMessage(provider: FuelCardProvider, matchingCount: Int) -> String? {
        guard provider != .none, matchingCount > 0 else { return nil }
        if matchingCount == 1 {
            return "Accepts your \(provider.displayName) card ahead"
        }
        return "\(matchingCount) stops ahead accept your \(provider.displayName) card"
    }

    /// Substrings matched against POI label and amenity brand tags (lowercased).
    public static func needles(for provider: FuelCardProvider) -> [String] {
        switch provider {
        case .none: []
        case .keyfuels: ["keyfuels", "key fuels"]
        case .ukFuels: ["uk fuels", "ukfuels", "texaco fleet", "texaco"]
        case .allStar: ["allstar", "all star", "allstar fuel"]
        case .esso: ["esso"]
        case .bp: ["bp", "bp connect", "bp pulse"]
        case .other: []
        }
    }

    private static func searchableText(for poi: TruckPoi) -> String {
        var parts = [poi.label.lowercased()]
        for amenity in poi.amenities {
            if amenity.hasPrefix("brand:") {
                parts.append(String(amenity.dropFirst(6)))
            }
        }
        return parts.joined(separator: " ")
    }
}
