import Contracts
import Testing

struct InspectionRecordTests {
    @Test func defaultDVSAItemsCoverAllZones() {
        let items = InspectionRecord.defaultDVSAItems()
        #expect(items.count >= 24)
        for zone in InspectionZone.allCases {
            #expect(items.contains(where: { $0.zone == zone }))
        }
    }

    @Test func completionFractionTracksResolvedItems() {
        var items = InspectionRecord.defaultDVSAItems()
        for index in items.indices {
            items[index].status = .pass
        }
        let record = InspectionRecord(vehicleLabel: "Artic", items: items)
        #expect(record.completionFraction == 1)
        #expect(record.isReadyToSave)
    }

    @Test func defectCountAndGrouping() {
        var items = InspectionRecord.defaultDVSAItems()
        items[0].status = .defect
        items[0].note = "Cracked mirror"
        items[1].status = .pass
        let record = InspectionRecord(vehicleLabel: "Rigid", items: items)
        #expect(record.defectCount == 1)
        #expect(record.itemsGroupedByZone().first?.zone == .cabMirrors)
    }
}
