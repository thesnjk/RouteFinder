import Contracts
import Foundation
import Testing
@testable import UI

struct InspectionReportPDFRendererTests {
    @Test func pdfDataIsNonEmptyForCompleteRecord() {
        var items = InspectionRecord.defaultDVSAItems()
        for index in items.indices {
            items[index].status = .pass
        }
        let record = InspectionRecord(
            vehicleLabel: "Test HGV",
            registrationPlate: "AB12 CDE",
            completedAt: Date(),
            items: items
        )
        let pdf = InspectionReportPDFRenderer.pdfData(from: record)
        #expect(!pdf.isEmpty)
        #expect(pdf.starts(with: Data("%PDF".utf8)))
    }
}
