import Contracts
import DataLayer
import Foundation
import Testing

@Suite("FleetAPISchemaFixtures")
struct FleetAPISchemaFixtureTests {
    @Test func proxyStatusFixtureDecodes() throws {
        let data = try Self.loadFixture("proxy-status.min.json")
        let status = try JSONDecoder().decode(FleetProxyDeskStatus.self, from: data)
        #expect(status.orsConfigured)
        #expect(status.routesToday == 12)
        #expect(status.orgName == "Norfolk Demo Depot")
        #expect(status.orgId == "22222222-2222-2222-2222-222222222222")
    }

    @Test func tripInspectionFixtureDecodes() throws {
        let data = try Self.loadFixture("trip-snapshot.inspection.json")
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let trip = try decoder.decode(FleetTrip.self, from: data)
        #expect(trip.status == .active)
        #expect(trip.stops.count == 2)
        #expect(trip.latestInspectionSummary?.defectCount == 2)
        #expect(trip.latestInspectionSummary?.vehicleLabel == "Artic 1")
        #expect(trip.driverLatitude == 52.7)
    }

    private static func loadFixture(_ name: String) throws -> Data {
        var dir = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        for _ in 0 ..< 8 {
            let candidate = dir
                .appendingPathComponent("Docs", isDirectory: true)
                .appendingPathComponent("fixtures", isDirectory: true)
                .appendingPathComponent("fleet", isDirectory: true)
                .appendingPathComponent(name)
            if FileManager.default.fileExists(atPath: candidate.path) {
                return try Data(contentsOf: candidate)
            }
            dir = dir.deletingLastPathComponent()
        }
        Issue.record("Missing Docs/fixtures/fleet/\(name) from \(#filePath)")
        throw FixtureLoadError.notFound(name)
    }

    private enum FixtureLoadError: Error {
        case notFound(String)
    }
}
