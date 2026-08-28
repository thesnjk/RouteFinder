import Contracts
import Foundation
import Testing

@Test func dispatchInspectionAnnouncerFirstDefectReport() {
    let summary = TripBriefInspectionSummary(
        vehicleLabel: "Artic 1",
        registrationPlate: "AB12 CDE",
        defectCount: 2,
        completedAt: Date(timeIntervalSince1970: 1_700_000_000)
    )
    #expect(
        DispatchInspectionAnnouncer.shouldAnnounce(
            previousSummary: nil,
            newSummary: summary,
            lastAnnounced: nil
        )
    )
}

@Test func dispatchInspectionAnnouncerSkipsRepeatAnnouncement() {
    let summary = TripBriefInspectionSummary(
        vehicleLabel: "Artic 1",
        defectCount: 1,
        completedAt: Date(timeIntervalSince1970: 1_700_000_000)
    )
    #expect(
        !DispatchInspectionAnnouncer.shouldAnnounce(
            previousSummary: summary,
            newSummary: summary,
            lastAnnounced: summary
        )
    )
}

@Test func dispatchInspectionAnnouncerDetectsIncreasedDefectCount() {
    let previous = TripBriefInspectionSummary(
        vehicleLabel: "Artic 1",
        defectCount: 1,
        completedAt: Date(timeIntervalSince1970: 1_700_000_000)
    )
    let updated = TripBriefInspectionSummary(
        vehicleLabel: "Artic 1",
        defectCount: 3,
        completedAt: Date(timeIntervalSince1970: 1_700_000_000)
    )
    #expect(
        DispatchInspectionAnnouncer.shouldAnnounce(
            previousSummary: previous,
            newSummary: updated,
            lastAnnounced: previous
        )
    )
}

@Test func dispatchInspectionAnnouncerDetectsNewCompletedInspection() {
    let previous = TripBriefInspectionSummary(
        vehicleLabel: "Artic 1",
        defectCount: 1,
        completedAt: Date(timeIntervalSince1970: 1_700_000_000)
    )
    let newer = TripBriefInspectionSummary(
        vehicleLabel: "Artic 1",
        defectCount: 1,
        completedAt: Date(timeIntervalSince1970: 1_700_100_000)
    )
    #expect(
        DispatchInspectionAnnouncer.shouldAnnounce(
            previousSummary: previous,
            newSummary: newer,
            lastAnnounced: previous
        )
    )
}

@Test func dispatchInspectionAnnouncerToastIncludesVehicleAndDefects() {
    let message = DispatchInspectionAnnouncer.toastMessage(
        for: TripBriefInspectionSummary(
            vehicleLabel: "Rigid",
            registrationPlate: "XY99 ZZZ",
            defectCount: 2,
            completedAt: Date()
        )
    )
    #expect(message.contains("Rigid (XY99 ZZZ)"))
    #expect(message.contains("2 defect(s)"))
}
