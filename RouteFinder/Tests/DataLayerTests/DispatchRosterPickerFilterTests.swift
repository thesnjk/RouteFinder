import Contracts
import Foundation
import Testing

@Suite("DispatchRosterPickerFilter")
struct DispatchRosterPickerFilterTests {
    @Test func allIncludesEverything() {
        #expect(
            DispatchRosterPickerFilter.includes(
                mode: .all,
                gpsAgeSeconds: nil,
                hasDefects: false,
                hasRosterData: false
            )
        )
        #expect(
            DispatchRosterPickerFilter.includes(
                mode: .all,
                gpsAgeSeconds: 12,
                hasDefects: true,
                hasRosterData: true
            )
        )
    }

    @Test func hideOfflineKeepsUnknownAndOnlineDropsOffline() {
        #expect(
            DispatchRosterPickerFilter.includes(
                mode: .hideOffline,
                gpsAgeSeconds: nil,
                hasDefects: false,
                hasRosterData: false
            )
        )
        #expect(
            DispatchRosterPickerFilter.includes(
                mode: .hideOffline,
                gpsAgeSeconds: 30,
                hasDefects: false,
                hasRosterData: true
            )
        )
        #expect(
            !DispatchRosterPickerFilter.includes(
                mode: .hideOffline,
                gpsAgeSeconds: nil,
                hasDefects: false,
                hasRosterData: true
            )
        )
    }

    @Test func defectsOnlyRequiresKnownDefects() {
        #expect(
            !DispatchRosterPickerFilter.includes(
                mode: .defectsOnly,
                gpsAgeSeconds: 10,
                hasDefects: false,
                hasRosterData: true
            )
        )
        #expect(
            !DispatchRosterPickerFilter.includes(
                mode: .defectsOnly,
                gpsAgeSeconds: nil,
                hasDefects: false,
                hasRosterData: false
            )
        )
        #expect(
            DispatchRosterPickerFilter.includes(
                mode: .defectsOnly,
                gpsAgeSeconds: nil,
                hasDefects: true,
                hasRosterData: true
            )
        )
    }

    @Test func filterOrderedIDsPreservesOrder() {
        let a = UUID()
        let b = UUID()
        let c = UUID()
        let status: [UUID: (gpsAgeSeconds: Int?, hasDefects: Bool)] = [
            a: (nil, false),
            b: (20, true),
            c: (5, false),
        ]
        let hideOffline = DispatchRosterPickerFilter.filterOrderedIDs(
            [a, b, c],
            mode: .hideOffline,
            statusByID: status
        )
        #expect(hideOffline == [b, c])

        let defects = DispatchRosterPickerFilter.filterOrderedIDs(
            [a, b, c],
            mode: .defectsOnly,
            statusByID: status
        )
        #expect(defects == [b])
    }
}
