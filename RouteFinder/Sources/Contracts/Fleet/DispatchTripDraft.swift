import Foundation

/// Editable stop row in the dispatch trip form.
public struct DispatchStopDraft: Identifiable, Sendable, Hashable {
    public let id: UUID
    public var label: String
    public var latitude: String
    public var longitude: String
    /// Optional earliest arrival (planning aid for ``StopTimeWindow``).
    public var earliestArrival: Date?
    /// Optional latest arrival (planning aid for ``StopTimeWindow``).
    public var latestArrival: Date?

    /// Creates a stop draft.
    public init(
        id: UUID = UUID(),
        label: String = "",
        latitude: String = "",
        longitude: String = "",
        earliestArrival: Date? = nil,
        latestArrival: Date? = nil
    ) {
        self.id = id
        self.label = label
        self.latitude = latitude
        self.longitude = longitude
        self.earliestArrival = earliestArrival
        self.latestArrival = latestArrival
    }

    /// Converts to a fleet stop when coordinates parse successfully.
    public func fleetStop(sequence: Int, role: FleetTripStop.Role) -> FleetTripStop? {
        guard let lat = Double(latitude.trimmingCharacters(in: .whitespaces)),
              let lon = Double(longitude.trimmingCharacters(in: .whitespaces)),
              !label.trimmingCharacters(in: .whitespaces).isEmpty else {
            return nil
        }
        return FleetTripStop(
            id: id,
            sequence: sequence,
            label: label.trimmingCharacters(in: .whitespaces),
            latitude: lat,
            longitude: lon,
            role: role
        )
    }

    /// Builds an optional stop time window when either bound is set.
    public func timeWindow() -> StopTimeWindow? {
        guard earliestArrival != nil || latestArrival != nil else { return nil }
        return StopTimeWindow(
            stopId: id,
            earliestArrival: earliestArrival,
            latestArrival: latestArrival
        )
    }
}

/// Dispatch trip form state before push.
public struct DispatchTripDraft: Sendable, Equatable {
    public var stops: [DispatchStopDraft]
    public var breakWindowStart: Date
    public var breakWindowEnd: Date
    public var breakDurationMinutes: Int
    public var breakLabel: String
    /// Optional gross weight in kilograms for ``FleetJobBrief``.
    public var grossWeightKgText: String
    /// Optional ADR class string for ``FleetJobBrief``.
    public var adrClassText: String
    /// When true, driver auto-finds route after push.
    public var autoFindRoute: Bool

    /// Creates an empty trip draft.
    public init(
        stops: [DispatchStopDraft] = [
            DispatchStopDraft(),
            DispatchStopDraft(),
        ],
        breakWindowStart: Date = Date().addingTimeInterval(3600),
        breakWindowEnd: Date = Date().addingTimeInterval(7200),
        breakDurationMinutes: Int = 45,
        breakLabel: String = "Afternoon break",
        grossWeightKgText: String = "",
        adrClassText: String = "",
        autoFindRoute: Bool = true
    ) {
        self.stops = stops
        self.breakWindowStart = breakWindowStart
        self.breakWindowEnd = breakWindowEnd
        self.breakDurationMinutes = breakDurationMinutes
        self.breakLabel = breakLabel
        self.grossWeightKgText = grossWeightKgText
        self.adrClassText = adrClassText
        self.autoFindRoute = autoFindRoute
    }

    /// UK demo template: Felixstowe → Midlands → Manchester.
    public static func ukDemoTemplate() -> DispatchTripDraft {
        let demoBreak = CompanyBreakAllocation.demoAfternoonBreak()
        return DispatchTripDraft(
            stops: [
                DispatchStopDraft(label: "Felixstowe Port", latitude: "51.9542", longitude: "1.3511"),
                DispatchStopDraft(label: "Midlands Hub", latitude: "52.4862", longitude: "-1.8904"),
                DispatchStopDraft(label: "Manchester Depot", latitude: "53.4808", longitude: "-2.2426"),
            ],
            breakWindowStart: demoBreak.window.start,
            breakWindowEnd: demoBreak.window.end,
            breakDurationMinutes: Int(demoBreak.durationSeconds / 60),
            breakLabel: demoBreak.label ?? "Afternoon break",
            grossWeightKgText: "44000",
            adrClassText: "",
            autoFindRoute: true
        )
    }

    /// Builds fleet stops with roles assigned by order.
    public func fleetStops() throws -> [FleetTripStop] {
        guard stops.count >= 2 else {
            throw FleetStoreError.invalidTrip("At least two stops are required.")
        }
        var built: [FleetTripStop] = []
        for (index, stop) in stops.enumerated() {
            let role: FleetTripStop.Role = switch index {
            case 0: .origin
            case stops.count - 1: .destination
            default: .via
            }
            guard let fleetStop = stop.fleetStop(sequence: index, role: role) else {
                throw FleetStoreError.invalidTrip("Stop \(index + 1) needs a label and valid coordinates.")
            }
            built.append(fleetStop)
        }
        return built
    }

    /// Builds company break allocation from form fields.
    public func companyBreaks() -> [CompanyBreakAllocation] {
        guard breakWindowEnd > breakWindowStart else { return [] }
        return [
            CompanyBreakAllocation(
                window: TimeWindow(start: breakWindowStart, end: breakWindowEnd),
                durationSeconds: TimeInterval(breakDurationMinutes * 60),
                label: breakLabel.isEmpty ? nil : breakLabel
            ),
        ]
    }

    /// Builds optional job brief from form fields.
    public func jobBrief() -> FleetJobBrief {
        let kg = Double(grossWeightKgText.trimmingCharacters(in: .whitespacesAndNewlines))
        let adr = adrClassText.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasWeight = kg != nil && (kg ?? 0) > 0
        let windows = stops.compactMap { $0.timeWindow() }
        return FleetJobBrief(
            grossWeightKg: hasWeight ? kg : nil,
            adrClass: adr.isEmpty ? nil : adr,
            timeWindows: windows,
            autoFindRoute: autoFindRoute,
            autoRehearse: false
        )
    }
}
