import Foundation
import Testing
@testable import RouteController

struct VehicleSpecificationCacheTests {
    @Test func cachedVehicleProfile_isExpired() {
        let recent = CachedVehicleProfile(
            profile: verifiedProfile(registrationMark: "AB12CDE"),
            cachedAt: Date().addingTimeInterval(-86400)
        )
        #expect(!recent.isExpired)

        let stale = CachedVehicleProfile(
            profile: verifiedProfile(registrationMark: "AB12CDE"),
            cachedAt: Date().addingTimeInterval(-(31 * 24 * 60 * 60))
        )
        #expect(stale.isExpired)
    }

    @Test func memoryHit_returnsProfile() async {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let cache = VehicleSpecificationCache(cacheDirectory: tempDir)
        let profile = verifiedProfile(registrationMark: "AB12CDE")

        await cache.store(profile, forKey: "AB12CDE")
        let result = await cache.profile(forKey: "AB12CDE")

        #expect(result == profile)
    }

    @Test func diskHit_promotesToMemory() async throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let profile = verifiedProfile(registrationMark: "XY99ZZZ")

        let writer = VehicleSpecificationCache(cacheDirectory: tempDir)
        await writer.store(profile, forKey: "XY99ZZZ")

        let reader = VehicleSpecificationCache(cacheDirectory: tempDir)
        let result = await reader.profile(forKey: "XY99ZZZ")

        #expect(result == profile)
    }

    @Test func expiredEntry_evicted() async throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        let profile = verifiedProfile(registrationMark: "OLD1REG")
        let staleEntry = CachedVehicleProfile(
            profile: profile,
            cachedAt: Date().addingTimeInterval(-(31 * 24 * 60 * 60))
        )
        let data = try JSONEncoder().encode(staleEntry)
        let fileURL = tempDir.appendingPathComponent("OLD1REG.json")
        try data.write(to: fileURL, options: .atomic)

        let cache = VehicleSpecificationCache(cacheDirectory: tempDir)
        let result = await cache.profile(forKey: "OLD1REG")

        #expect(result == nil)
        #expect(!FileManager.default.fileExists(atPath: fileURL.path))
    }

    @Test func transientProfile_notStored() async {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let cache = VehicleSpecificationCache(cacheDirectory: tempDir)
        let transient = VehicleSpecificationProfileBuilder.build(
            registrationMark: "AB12CDE",
            vehicleClass: .passengerCar,
            make: "Unknown",
            model: "Unknown",
            source: .transientHeuristic
        )

        await cache.store(transient, forKey: "AB12CDE")
        let result = await cache.profile(forKey: "AB12CDE")

        #expect(result == nil)
    }

    @Test func corruptFile_deleted() async throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        let fileURL = tempDir.appendingPathComponent("CORRUPT.json")
        try Data("{ not valid json".utf8).write(to: fileURL, options: .atomic)

        let cache = VehicleSpecificationCache(cacheDirectory: tempDir)
        let result = await cache.profile(forKey: "CORRUPT")

        #expect(result == nil)
        #expect(!FileManager.default.fileExists(atPath: fileURL.path))
    }

    @Test func cacheKeyEquivalence_resolvesSpacedVariants() async {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let cache = VehicleSpecificationCache(cacheDirectory: tempDir)
        let profile = verifiedProfile(registrationMark: "AU14TWZ")

        await cache.store(profile, forKey: "AU14 TWZ")
        let result = await cache.profile(forKey: "au14twz")

        #expect(result == profile)
    }

    @Test func clear_removesAllEntries() async throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let cache = VehicleSpecificationCache(cacheDirectory: tempDir)
        let profile = verifiedProfile(registrationMark: "CL34RME")

        await cache.store(profile, forKey: "CL34RME")
        try await cache.clear()
        let result = await cache.profile(forKey: "CL34RME")

        #expect(result == nil)
    }

    private func verifiedProfile(registrationMark: String) -> VehicleSpecificationProfile {
        VehicleSpecificationProfileBuilder.build(
            registrationMark: registrationMark,
            vehicleClass: .passengerCar,
            make: "FORD",
            model: "FOCUS",
            source: .verifiedAPI
        )
    }
}
