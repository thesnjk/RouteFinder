import Contracts
import DataLayer
import Foundation
import Testing

@Suite("APIUsageLedger", .serialized)
struct APIUsageLedgerTests {
    @Test func recordIncrementsDailyCount() async {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("api-usage-\(UUID().uuidString).json")
        let ledger = APIUsageLedger(storageURL: url)
        let day = Calendar.current.date(from: DateComponents(year: 2026, month: 8, day: 29))!

        await ledger.record(provider: .orsRoute, at: day)
        await ledger.record(provider: .orsRoute, at: day)
        await ledger.record(provider: .tomTomFlow, at: day)

        let summary = await ledger.summary(on: day)
        #expect(summary.count(for: .orsRoute) == 2)
        #expect(summary.count(for: .tomTomFlow) == 1)
        #expect(summary.totalCount == 3)
    }

    @Test func persistenceRoundTrip() async throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("api-usage-\(UUID().uuidString).json")
        let day = Calendar.current.date(from: DateComponents(year: 2026, month: 8, day: 29))!

        do {
            let first = APIUsageLedger(storageURL: url)
            await first.record(provider: .overpass, at: day)
            await first.record(provider: .overpass, at: day)
        }

        let reloaded = APIUsageLedger(storageURL: url)
        let summary = await reloaded.summary(on: day)
        #expect(summary.count(for: .overpass) == 2)
    }

    @Test func budgetExceededBlocksNonCriticalPolls() async {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("api-usage-\(UUID().uuidString).json")
        let ledger = APIUsageLedger(storageURL: url)
        let day = Calendar.current.date(from: DateComponents(year: 2026, month: 8, day: 29))!
        let limit = APIUsageBudget.defaultBudget(for: .tomTomFlow).softDailyLimit

        await ledger.replaceAllCounts([
            Self.dayKey(for: day): [.tomTomFlow: limit]
        ])

        #expect(await ledger.isOverSoftBudget(provider: .tomTomFlow, on: day))
        #expect(await ledger.allowsNonCriticalRequest(provider: .tomTomFlow, on: day) == false)
        #expect(await ledger.allowsNonCriticalRequest(provider: .orsRoute, on: day))
    }

    @Test func budgetBannerListsOverBudgetProviders() async {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("api-usage-\(UUID().uuidString).json")
        let ledger = APIUsageLedger(storageURL: url)
        let day = Calendar.current.date(from: DateComponents(year: 2026, month: 8, day: 29))!
        let overpassLimit = APIUsageBudget.defaultBudget(for: .overpass).softDailyLimit

        await ledger.replaceAllCounts([
            Self.dayKey(for: day): [.overpass: overpassLimit]
        ])

        let banner = await ledger.budgetBannerMessage(on: day)
        #expect(banner?.contains("Overpass") == true)
        #expect(banner?.contains("paused") == true)
    }

    private static func dayKey(for date: Date) -> String {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", components.year ?? 0, components.month ?? 0, components.day ?? 0)
    }
}
