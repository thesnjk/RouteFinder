import Foundation

/// Desk vehicle-picker / roster display mode for 5–15 truck throughput.
public enum DispatchRosterPickerMode: String, Sendable, CaseIterable, Codable, Equatable {
    /// Show every text-filtered vehicle.
    case all
    /// Hide cabs with no published GPS once roster data exists.
    case hideOffline
    /// Show only cabs with walkaround defects on the latest inspection.
    case defectsOnly
}

/// Filters desk picker/roster rows after label/plate text filter (caller still applies cap 20).
public enum DispatchRosterPickerFilter: Sendable {
    /// Whether a vehicle should appear for the given mode and roster status.
    ///
    /// - Parameters:
    ///   - mode: Picker mode.
    ///   - gpsAgeSeconds: Age of published GPS, or nil when absent.
    ///   - hasDefects: Latest inspection has defects.
    ///   - hasRosterData: Whether an active-trip poll result exists for this vehicle.
    public static func includes(
        mode: DispatchRosterPickerMode,
        gpsAgeSeconds: Int?,
        hasDefects: Bool,
        hasRosterData: Bool
    ) -> Bool {
        switch mode {
        case .all:
            return true
        case .hideOffline:
            if !hasRosterData { return true }
            return gpsAgeSeconds != nil
        case .defectsOnly:
            return hasRosterData && hasDefects
        }
    }

    /// Preserves `orderedIDs` order while applying mode using optional roster status.
    public static func filterOrderedIDs(
        _ orderedIDs: [UUID],
        mode: DispatchRosterPickerMode,
        statusByID: [UUID: (gpsAgeSeconds: Int?, hasDefects: Bool)]
    ) -> [UUID] {
        orderedIDs.filter { id in
            if let status = statusByID[id] {
                return includes(
                    mode: mode,
                    gpsAgeSeconds: status.gpsAgeSeconds,
                    hasDefects: status.hasDefects,
                    hasRosterData: true
                )
            }
            return includes(
                mode: mode,
                gpsAgeSeconds: nil,
                hasDefects: false,
                hasRosterData: false
            )
        }
    }
}
