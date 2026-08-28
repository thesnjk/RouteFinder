import Foundation

/// Compact walkaround inspection summary for trip briefs and fleet handoff.
public struct TripBriefInspectionSummary: Sendable, Hashable, Codable, Equatable {
    /// Display label for the inspected vehicle.
    public let vehicleLabel: String
    /// Optional registration plate.
    public let registrationPlate: String?
    /// Number of checklist items marked defect.
    public let defectCount: Int
    /// When the walkaround was completed.
    public let completedAt: Date

    /// Creates an inspection summary for trip brief formatting.
    public init(
        vehicleLabel: String,
        registrationPlate: String? = nil,
        defectCount: Int,
        completedAt: Date
    ) {
        self.vehicleLabel = vehicleLabel
        self.registrationPlate = registrationPlate
        self.defectCount = defectCount
        self.completedAt = completedAt
    }

    /// Builds a summary from a saved walkaround record.
    public init(record: InspectionRecord) {
        vehicleLabel = record.vehicleLabel
        registrationPlate = record.registrationPlate
        defectCount = record.defectCount
        completedAt = record.completedAt ?? record.createdAt
    }
}
