import Contracts
import Foundation
import Testing

@Test func committedRouteTollSummaryNilWhenEmpty() {
    #expect(VoiceAssistResponseFormatter.committedRouteTollSummary(advisories: []) == nil)
    #expect(VoiceAssistResponseFormatter.committedRouteTollAnnouncement(advisories: []) == nil)
}

@Test func committedRouteTollAnnouncementIncludesIndicativeTotal() {
    let advisories = UKTollAdvisoryCatalog.all.filter {
        $0.id == "dartford-crossing" || $0.id == "m6-toll"
    }
    #expect(advisories.count == 2)
    let summary = VoiceAssistResponseFormatter.committedRouteTollSummary(advisories: advisories)
    #expect(summary != nil)
    #expect(summary?.contains("Dartford") == true)
    #expect(summary?.contains("M6 Toll") == true)
    #expect(summary?.contains("Indicative tolls") == true)

    let spoken = VoiceAssistResponseFormatter.committedRouteTollAnnouncement(advisories: advisories)
    #expect(spoken?.contains("Indicative only") == true)
    #expect(spoken != "No named tolls on this route.")
}

@Test func tollRouteSignatureStableOrderIndependent() {
    let a = UKTollAdvisoryCatalog.all.first { $0.id == "dartford-crossing" }!
    let b = UKTollAdvisoryCatalog.all.first { $0.id == "m6-toll" }!
    let left = VoiceAssistResponseFormatter.tollRouteSignature(advisories: [a, b])
    let right = VoiceAssistResponseFormatter.tollRouteSignature(advisories: [b, a])
    #expect(left == right)
    #expect(!left.isEmpty)
}

@Test func committedRouteTollSummaryNonNilForDartfordAndM6() {
    let advisories = UKTollAdvisoryCatalog.all.filter {
        $0.id == "dartford-crossing" || $0.id == "m6-toll"
    }
    let summary = VoiceAssistResponseFormatter.committedRouteTollSummary(advisories: advisories)
    #expect(summary != nil)
    #expect(summary?.contains("Indicative tolls") == true)
}

@Test func committedRouteTollSummaryNilForSevernOnly() {
    let severn = UKTollAdvisoryCatalog.all.first { $0.id == "severn-crossings" }!
    #expect(severn.indicativeCostGBP == nil)
    // Free-crossing still yields a names-only summary (HUD can show it); GBP total stays nil.
    let summary = VoiceAssistResponseFormatter.committedRouteTollSummary(advisories: [severn])
    #expect(summary == "Severn Bridge / Second Severn Crossing")
    #expect(UKTollAdvisory.indicativeRouteTotalLabel(advisories: [severn]) == nil)
    #expect(VoiceAssistResponseFormatter.committedRouteTollSummary(advisories: []) == nil)
}
