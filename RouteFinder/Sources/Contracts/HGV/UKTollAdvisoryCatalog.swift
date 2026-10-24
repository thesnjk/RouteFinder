import Foundation

/// A named UK toll / tolled crossing advisory with optional static indicative £.
///
/// Prices are **not** live tariffs — operators change class-based rates. Always check
/// the linked operator / GOV.UK page before travel.
public struct UKTollAdvisory: Sendable, Hashable, Codable, Identifiable, Equatable {
    public let id: String
    public let name: String
    public let latitude: Double
    public let longitude: Double
    /// Distance from the toll point within which a route vertex counts as a hit.
    public let approachRadiusMeters: Double
    /// Short driver-facing hint (payment scheme, directionality, free-context).
    public let hint: String
    /// Optional official operator information URL.
    public let infoURL: URL?
    /// Static indicative single-crossing cost in GBP (planning aid only).
    public let indicativeCostGBP: Double?
    /// Short note clarifying the £ figure (e.g. day rate / class).
    public let indicativeCostNote: String?

    public init(
        id: String,
        name: String,
        latitude: Double,
        longitude: Double,
        approachRadiusMeters: Double = 2_500,
        hint: String,
        infoURL: URL? = nil,
        indicativeCostGBP: Double? = nil,
        indicativeCostNote: String? = nil
    ) {
        self.id = id
        self.name = name
        self.latitude = latitude
        self.longitude = longitude
        self.approachRadiusMeters = approachRadiusMeters
        self.hint = hint
        self.infoURL = infoURL
        self.indicativeCostGBP = indicativeCostGBP
        self.indicativeCostNote = indicativeCostNote
    }

    /// Catalog point as a route coordinate.
    public var coordinate: Coordinate {
        Coordinate(latitude: latitude, longitude: longitude)
    }

    /// Driver-facing “Indicative ~£X” line when a static £ is seeded.
    public var indicativeCostLabel: String? {
        guard let indicativeCostGBP else { return nil }
        let amount = String(format: "£%.2f", indicativeCostGBP)
        if let indicativeCostNote, !indicativeCostNote.isEmpty {
            return "Indicative ~\(amount) (\(indicativeCostNote))"
        }
        return "Indicative ~\(amount)"
    }

    /// Sum of non-nil indicative costs on matched advisories (planning total only).
    public static func indicativeRouteTotalGBP(advisories: [UKTollAdvisory]) -> Double? {
        let amounts = advisories.compactMap(\.indicativeCostGBP)
        guard !amounts.isEmpty else { return nil }
        return amounts.reduce(0, +)
    }

    /// Formatted route total, e.g. `Indicative tolls ~£18.00`.
    public static func indicativeRouteTotalLabel(advisories: [UKTollAdvisory]) -> String? {
        guard let total = indicativeRouteTotalGBP(advisories: advisories) else { return nil }
        return String(format: "Indicative tolls ~£%.2f", total)
    }
}

/// Hand-authored UK toll / crossing points for along-route advisories.
///
/// Indicative £ figures are static planning aids (approx. day / single-crossing rates for
/// larger goods vehicles where published) — **not** live class tables. As-of **2025-10**
/// public operator pages; always verify before travel.
public enum UKTollAdvisoryCatalog: Sendable {
    /// All seeded advisories (≈16 major UK truck-relevant tolls / crossings).
    public static let all: [UKTollAdvisory] = [
        UKTollAdvisory(
            id: "m6-toll",
            name: "M6 Toll",
            latitude: 52.6500,
            longitude: -1.7500,
            approachRadiusMeters: 4_000,
            hint: "Private motorway — class-based charges; tag or account.",
            infoURL: URL(string: "https://www.m6toll.co.uk/"),
            indicativeCostGBP: 13.00,
            indicativeCostNote: "indicative HGV class; check M6 Toll"
        ),
        UKTollAdvisory(
            id: "dartford-crossing",
            name: "Dartford Crossing",
            latitude: 51.4640,
            longitude: 0.2580,
            approachRadiusMeters: 3_500,
            hint: "Dart Charge — pay by midnight next day for most vehicles.",
            infoURL: URL(string: "https://www.gov.uk/dart-charge"),
            indicativeCostGBP: 6.00,
            indicativeCostNote: "indicative HGV day; check GOV.UK"
        ),
        UKTollAdvisory(
            id: "mersey-gateway",
            name: "Mersey Gateway",
            latitude: 53.3500,
            longitude: -2.7300,
            approachRadiusMeters: 3_000,
            hint: "Merseyflow account or pay-as-you-go. Silver Jubilee Bridge free for most local traffic.",
            infoURL: URL(string: "https://www.merseyflow.co.uk/"),
            indicativeCostGBP: 4.00,
            indicativeCostNote: "indicative; check Merseyflow class"
        ),
        UKTollAdvisory(
            id: "severn-crossings",
            name: "Severn Bridge / Second Severn Crossing",
            latitude: 51.5900,
            longitude: -2.7000,
            approachRadiusMeters: 4_000,
            hint: "Severn Bridge tolls ended 2018 — free crossing. Historic entry retained for map context.",
            infoURL: URL(string: "https://www.gov.uk/government/news/severn-crossing-tolls-to-end")
        ),
        UKTollAdvisory(
            id: "humber-bridge",
            name: "Humber Bridge",
            latitude: 53.7070,
            longitude: -0.4500,
            approachRadiusMeters: 2_500,
            hint: "Tolled bridge — HGV class rates apply. Pay at plaza or check operator site.",
            infoURL: URL(string: "https://www.humberbridge.co.uk/"),
            indicativeCostGBP: 5.00,
            indicativeCostNote: "indicative; check Humber Bridge"
        ),
        UKTollAdvisory(
            id: "tyne-tunnel",
            name: "Tyne Tunnel",
            latitude: 54.9860,
            longitude: -1.4800,
            approachRadiusMeters: 2_500,
            hint: "TT2 account recommended for HGVs. Day rates vary by vehicle class.",
            infoURL: URL(string: "https://www.tt2.co.uk/"),
            indicativeCostGBP: 3.00,
            indicativeCostNote: "indicative; check TT2"
        ),
        UKTollAdvisory(
            id: "tamar-bridge",
            name: "Tamar Bridge",
            latitude: 50.4080,
            longitude: -4.2040,
            approachRadiusMeters: 2_000,
            hint: "Toll westbound (into Cornwall). Check current HGV tariffs with the authority.",
            infoURL: URL(string: "https://www.tamarcrossings.org.uk/"),
            indicativeCostGBP: 3.00,
            indicativeCostNote: "westbound indicative; check authority"
        ),
        UKTollAdvisory(
            id: "forth-road-bridge",
            name: "Forth Road Bridge / Queensferry Crossing",
            latitude: 56.0000,
            longitude: -3.4000,
            approachRadiusMeters: 3_500,
            hint: "Queensferry Crossing is the main HGV route; Forth Road Bridge restricted. No toll on Queensferry.",
            infoURL: URL(string: "https://www.transport.gov.scot/")
        ),
        UKTollAdvisory(
            id: "erksine-bridge",
            name: "Erskine Bridge",
            latitude: 55.9200,
            longitude: -4.4600,
            approachRadiusMeters: 2_000,
            hint: "Scotland — free for most traffic; check any temporary restrictions.",
            infoURL: nil
        ),
        UKTollAdvisory(
            id: "clyde-tunnel",
            name: "Clyde Tunnel",
            latitude: 55.8600,
            longitude: -4.3200,
            approachRadiusMeters: 1_500,
            hint: "Height/vehicle restrictions may apply — verify before routing HGV through tunnels.",
            infoURL: nil
        ),
        UKTollAdvisory(
            id: "blackwall-tunnel",
            name: "Blackwall Tunnel",
            latitude: 51.5030,
            longitude: 0.0030,
            approachRadiusMeters: 2_000,
            hint: "Not a toll — height and HGV restrictions; Silvertown Tunnel may divert traffic.",
            infoURL: URL(string: "https://tfl.gov.uk/")
        ),
        UKTollAdvisory(
            id: "silvertown-tunnel",
            name: "Silvertown Tunnel",
            latitude: 51.5020,
            longitude: 0.0200,
            approachRadiusMeters: 2_500,
            hint: "User charge applies — check TfL for HGV rates and exemptions.",
            infoURL: URL(string: "https://tfl.gov.uk/modes/driving/silvertown-tunnel"),
            indicativeCostGBP: 4.00,
            indicativeCostNote: "indicative TfL user charge; check class"
        ),
        UKTollAdvisory(
            id: "conwy-tunnel",
            name: "Conwy Tunnel (A55)",
            latitude: 53.2800,
            longitude: -3.8300,
            approachRadiusMeters: 2_000,
            hint: "Free trunk road tunnel — height/ADR awareness; not a toll plaza.",
            infoURL: nil
        ),
        UKTollAdvisory(
            id: "durham-a1m",
            name: "A1(M) Durham (historic toll context)",
            latitude: 54.7800,
            longitude: -1.5800,
            approachRadiusMeters: 3_000,
            hint: "No current toll on A1(M) Durham — catalog entry for corridor awareness only.",
            infoURL: nil
        ),
        UKTollAdvisory(
            id: "itchen-bridge",
            name: "Itchen Bridge (Southampton)",
            latitude: 50.8970,
            longitude: -1.3850,
            approachRadiusMeters: 1_500,
            hint: "Local toll bridge — check Southampton City Council for current charges.",
            infoURL: URL(string: "https://www.southampton.gov.uk/"),
            indicativeCostGBP: 1.00,
            indicativeCostNote: "indicative local; check council"
        ),
        UKTollAdvisory(
            id: "whitchurch-bridge",
            name: "Whitchurch Bridge (Thames)",
            latitude: 51.4870,
            longitude: -1.0850,
            approachRadiusMeters: 1_200,
            hint: "Private toll bridge — weight limits; unsuitable for many HGVs.",
            infoURL: nil
        ),
    ]

    /// Looks up an advisory by stable id.
    public static func advisory(id: String) -> UKTollAdvisory? {
        all.first { $0.id == id }
    }
}
