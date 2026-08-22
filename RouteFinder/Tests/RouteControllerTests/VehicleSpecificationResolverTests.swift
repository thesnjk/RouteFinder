import Contracts
import CoreLocation
import Foundation
import Testing
@testable import RouteController

struct VehicleSpecificationResolverTests {
    @Test func normalizesRegistrationMark() async throws {
        let coordinator = VehicleRegistryCoordinator(
            networkProviders: [],
            heuristicProvider: HeuristicSpecificationSynthesizer()
        )

        let profile = try await coordinator.resolveVehicle(registrationMark: " ab 12 cde! ")
        #expect(profile.registrationMark == "AB12CDE")
    }

    @Test func emptyRegistration_throws() async {
        let coordinator = VehicleRegistryCoordinator(
            networkProviders: [],
            heuristicProvider: HeuristicSpecificationSynthesizer()
        )

        do {
            _ = try await coordinator.resolveVehicle(registrationMark: "   ")
            Issue.record("Expected emptyRegistration error")
        } catch let error as VehicleRegistryError {
            if case .emptyRegistration = error {
                #expect(Bool(true))
            } else {
                Issue.record("Wrong error type: \(error)")
            }
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test func heuristicClassifiesHGVKeywords() async throws {
        let synthesizer = HeuristicSpecificationSynthesizer()
        let profile = try await synthesizer.fetchSpecifications(for: "DAF-FLEET-01")

        #expect(profile.vehicleClass == .heavyGoodsVehicle)
        #expect(profile.grossWeightKilograms == 18_000)
        #expect(profile.lengthMeters == 12.0)
        #expect(profile.widthMeters == 2.55)
        #expect(profile.heightMeters == 4.0)
        #expect(profile.axleCount == 3)
        #expect(profile.source == .fallbackSynthesized)
    }

    @Test func heuristicClassifiesLCVKeywords() async throws {
        let synthesizer = HeuristicSpecificationSynthesizer()
        let profile = try await synthesizer.fetchSpecifications(for: "TRANSIT-99")

        #expect(profile.vehicleClass == .lightCommercialVehicle)
        #expect(profile.grossWeightKilograms == 3_500)
        #expect(profile.lengthMeters == 6.0)
        #expect(profile.widthMeters == 2.0)
        #expect(profile.heightMeters == 2.5)
        #expect(profile.axleCount == 2)
        #expect(profile.source == .fallbackSynthesized)
    }

    @Test func heuristicDefaultsToCar() async throws {
        let synthesizer = HeuristicSpecificationSynthesizer()
        let profile = try await synthesizer.fetchSpecifications(for: "AB12CDE")

        #expect(profile.vehicleClass == .passengerCar)
        #expect(profile.grossWeightKilograms == 1_600)
        #expect(profile.lengthMeters == 4.5)
        #expect(profile.widthMeters == 1.8)
        #expect(profile.heightMeters == 1.4)
        #expect(profile.axleCount == 2)
        #expect(profile.source == .fallbackSynthesized)
    }

    @Test func manualClassOverrideForcesDimensions() async throws {
        let mockProvider = MockVehicleRegistryProvider { _ in
            VehicleSpecificationProfileBuilder.build(
                registrationMark: "AB12CDE",
                vehicleClass: .passengerCar,
                make: "FORD",
                model: "FOCUS"
            )
        }

        let coordinator = VehicleRegistryCoordinator(networkProviders: [mockProvider])
        let profile = try await coordinator.resolveVehicle(
            registrationMark: "AB12CDE",
            manualClassOverride: .heavyGoodsVehicle
        )

        #expect(profile.vehicleClass == .heavyGoodsVehicle)
        #expect(profile.lengthMeters == 12.0)
        #expect(profile.make == "FORD")
        #expect(profile.model == "FOCUS")
    }

    @Test func regCheckXMLExtractsVehicleJson() throws {
        let xml = """
        <?xml version="1.0" encoding="utf-8"?>
        <Vehicle xmlns="http://regcheck.org.uk">
          <vehicleJson>{"Description":"FORD TRANSIT 2.0","CarMake":{"CurrentTextValue":"FORD"},"CarModel":{"CurrentTextValue":"TRANSIT"},"FuelType":{"CurrentTextValue":"Diesel"},"GrossWeight":"3200"}</vehicleJson>
        </Vehicle>
        """

        let payload = try RegCheckResponseParser.parse(data: Data(xml.utf8), registrationMark: "AB12CDE")
        #expect(payload.resolvedMake == "FORD")
        #expect(payload.resolvedModel == "TRANSIT")
        #expect(payload.classifyVehicleClass() == .lightCommercialVehicle)

        let profile = payload.toSpecificationProfile(registrationMark: "AB12CDE")
        #expect(profile.vehicleClass == .lightCommercialVehicle)
        #expect(profile.grossWeightKilograms == 3_200)
    }

    @Test func regCheckXMLWithXmlnsStillParses() throws {
        let xml = """
        <Vehicle xmlns="http://regcheck.org.uk" xmlns:b="http://schemas.example">
          <vehicleJson><![CDATA[{"Description":"DAF XF","CarMake":{"CurrentTextValue":"DAF"},"GrossWeight":"18000"}]]></vehicleJson>
        </Vehicle>
        """
        let payload = try RegCheckResponseParser.parse(data: Data(xml.utf8), registrationMark: "DAF01")
        #expect(payload.resolvedMake == "DAF")
        #expect(payload.classifyVehicleClass() == .heavyGoodsVehicle)
    }

    @Test func regCheckRegexFallbackRecoversFields() throws {
        let malformed = """
        <vehicleJson>{"Description":"SCANIA R450","CarMake":{"CurrentTextValue":"SCANIA"}, broken json</vehicleJson>
        """
        let payload = try RegCheckResponseParser.parse(data: Data(malformed.utf8), registrationMark: "SC01")
        #expect(payload.resolvedMake == "SCANIA")
        #expect(payload.description == "SCANIA R450")
    }

    @Test func regCheckRegexFallbackRecoversHeight() throws {
        let malformed = """
        <vehicleJson>{"Description":"DAF XF","CarMake":{"CurrentTextValue":"DAF"},"Height":"4.2","Weight":"44000"}</vehicleJson>
        """
        let payload = try RegCheckResponseParser.parse(data: Data(malformed.utf8), registrationMark: "DAF02")
        #expect(payload.resolvedHeightMeters() == 4.2)
        #expect(payload.resolvedGrossWeightKilograms() == 44_000)
    }

    @Test func regCheckParsesPowerKwToHorsepower() throws {
        let json = """
        {"Description":"FORD FOCUS 1.0","CarMake":{"CurrentTextValue":"FORD"},"CarModel":{"CurrentTextValue":"FOCUS"},"PowerKw":"110","BodyStyle":"Hatchback"}
        """
        let payload = try RegCheckResponseParser.parse(data: Data(json.utf8), registrationMark: "AB12CDE")
        #expect(payload.rawPayload.calculatedHP == 148)
        #expect(payload.classifyVehicleClass() == .passengerCar)

        let profile = payload.toSpecificationProfile(registrationMark: "AB12CDE")
        #expect(profile.enginePowerHorsepower == 148)
        #expect(profile.vehicleClass == .passengerCar)
    }

    @Test func regCheckBodyStyleIdentifiesHGV() throws {
        let json = """
        {"Description":"VOLVO FH","CarMake":{"CurrentTextValue":"VOLVO"},"BodyStyle":"Articulated HGV","PowerKw":"330"}
        """
        let payload = try RegCheckResponseParser.parse(data: Data(json.utf8), registrationMark: "VO01HGV")
        #expect(payload.rawPayload.isCommercialHGV)
        #expect(payload.classifyVehicleClass() == .heavyGoodsVehicle)
    }

    @Test func regCheckConsumerCarDefaultsToPassenger() throws {
        let json = """
        {"Description":"FORD FOCUS ZETEC","CarMake":{"CurrentTextValue":"FORD"},"CarModel":{"CurrentTextValue":"FOCUS"},"EngineSize":{"CurrentTextValue":"999"},"BodyStyle":"Hatchback"}
        """
        let payload = try RegCheckResponseParser.parse(data: Data(json.utf8), registrationMark: "AB12CDE")
        #expect(payload.classifyVehicleClass() == .passengerCar)
        #expect(payload.rawPayload.isCommercialHGV == false)
    }

    @Test func regCheckParseFailureThrows() {
        let garbage = Data("not xml or json".utf8)
        do {
            _ = try RegCheckResponseParser.parse(data: garbage, registrationMark: "XX00XXX")
            Issue.record("Expected parse failure")
        } catch let error as RegCheckParseError {
            if case .unableToParse(let mark) = error {
                #expect(mark == "XX00XXX")
            } else {
                Issue.record("Wrong RegCheckParseError case")
            }
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test func keywordClassifierAvoidsMANSubstring() {
        #expect(VehicleProfileClassifier.classify(from: "COMMAND CENTER") == .passengerCar)
        #expect(VehicleProfileClassifier.classify(from: "ROMAN EMPIRE TOUR") == .passengerCar)
        #expect(VehicleProfileClassifier.classify(from: "MAN TGX 26.480") == .heavyGoodsVehicle)
    }

    @Test func enginePowerFlowsToRegistryProfile() throws {
        let json = """
        {"Description":"FORD FOCUS","CarMake":{"CurrentTextValue":"FORD"},"PowerKw":"110"}
        """
        let payload = try RegCheckResponseParser.parse(data: Data(json.utf8), registrationMark: "AB12CDE")
        let profile = payload.toSpecificationProfile(registrationMark: "AB12CDE")
        let registryProfile = profile.toRegistryProfile()
        #expect(registryProfile.enginePowerHP == 148)
    }

    @Test func regCheckParsesVehicleDataWrapper() throws {
        let json = """
        {"VehicleData":{"Description":"VOLVO XC60 D5","CarMake":{"CurrentTextValue":"VOLVO"},"CarModel":{"CurrentTextValue":"XC60"},"BodyStyle":"SUV","PowerBhp":"235","Length":"4.68","Width":"1.90","Wheelbase":"2.86"}}
        """
        let payload = try RegCheckResponseParser.parse(data: Data(json.utf8), registrationMark: "VO60SUV")
        #expect(payload.resolvedMake == "VOLVO")
        #expect(payload.classifyVehicleClass() == .passengerCar)
        #expect(payload.rawPayload.calculatedHP == 235)

        let profile = payload.toSpecificationProfile(registrationMark: "VO60SUV")
        #expect(profile.vehicleClass == .passengerCar)
        #expect(profile.lengthMeters == 4.68)
        #expect(profile.widthMeters == 1.90)
        #expect(profile.wheelbaseMeters == 2.86)
    }

    @Test func regCheckPowerBhpTakesPriorityOverPowerKw() throws {
        let json = """
        {"Description":"BMW 320D","CarMake":{"CurrentTextValue":"BMW"},"PowerBhp":"190","PowerKw":"110","BodyStyle":"Saloon"}
        """
        let payload = try RegCheckResponseParser.parse(data: Data(json.utf8), registrationMark: "BM20W")
        #expect(payload.rawPayload.calculatedHP == 190)
    }

    @Test func regCheckVolvoXC60NotClassifiedAsHGV() throws {
        let json = """
        {"Description":"VOLVO XC60 D5 AWD","CarMake":{"CurrentTextValue":"VOLVO"},"CarModel":{"CurrentTextValue":"XC60"},"BodyStyle":"SUV","PowerKw":"173"}
        """
        let payload = try RegCheckResponseParser.parse(data: Data(json.utf8), registrationMark: "VO60XC")
        #expect(payload.classifyVehicleClass() == .passengerCar)

        let profile = payload.toSpecificationProfile(registrationMark: "VO60XC")
        #expect(profile.vehicleClass == .passengerCar)
        #expect(profile.lengthMeters == 4.68)
        #expect(profile.widthMeters == 1.90)
        #expect(profile.wheelbaseMeters == 2.86)
    }

    @Test func coordinatorFallsBackOnProviderFailure() async throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let cache = VehicleSpecificationCache(cacheDirectory: tempDir)

        let failingProvider = MockVehicleRegistryProvider { _ in
            throw VehicleRegistryError.networkFailure("offline")
        }

        let coordinator = VehicleRegistryCoordinator(
            networkProviders: [failingProvider],
            cache: cache
        )
        let profile = try await coordinator.resolveVehicle(registrationMark: "AB12CDE")

        #expect(profile.vehicleClass == .passengerCar)
        #expect(profile.registrationMark == "AB12CDE")
        #expect(profile.source == .fallbackSynthesized)
    }

    @Test func coordinatorTimeoutProceedsToNextProvider() async throws {
        let slowProvider = MockVehicleRegistryProvider { _ in
            try await Task.sleep(nanoseconds: 5_000_000_000)
            return VehicleSpecificationProfileBuilder.build(
                registrationMark: "SLOW",
                vehicleClass: .passengerCar,
                make: "Slow",
                model: "Car"
            )
        }

        let fastProvider = MockVehicleRegistryProvider { registration in
            VehicleSpecificationProfileBuilder.build(
                registrationMark: registration,
                vehicleClass: .heavyGoodsVehicle,
                make: "DAF",
                model: "XF"
            )
        }

        let coordinator = VehicleRegistryCoordinator(networkProviders: [slowProvider, fastProvider])
        let profile = try await coordinator.resolveVehicle(registrationMark: "TIMEOUT01")

        #expect(profile.vehicleClass == .heavyGoodsVehicle)
        #expect(profile.make == "DAF")
    }

    @Test func toRegistryProfileMapsLCVToHGVMode() {
        let profile = VehicleSpecificationProfileBuilder.build(
            registrationMark: "AB12CDE",
            vehicleClass: .lightCommercialVehicle,
            make: "FORD",
            model: "TRANSIT"
        )

        let registryProfile = profile.toRegistryProfile()
        #expect(registryProfile.isHGVMode)
        #expect(registryProfile.vehicleType == .hgv)
        #expect(registryProfile.lengthM == 6.0)
        #expect(registryProfile.weightTonnes == 3.5)
    }

    @Test func orientedFootprintProducesClosedRing() {
        let profile = VehicleSpecificationProfileBuilder.build(
            registrationMark: "AB12CDE",
            vehicleClass: .passengerCar,
            make: "Test",
            model: "Car"
        )

        let center = CLLocationCoordinate2D(latitude: 51.5, longitude: -0.12)
        let ring = profile.orientedFootprint(center: center, bearingDegrees: 45)

        #expect(ring.count == 5)
        #expect(ring.first?.latitude == ring.last?.latitude)
        #expect(ring.first?.longitude == ring.last?.longitude)
    }

    @Test func coordinator_cacheHit_avoidsProvider() async throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let cache = VehicleSpecificationCache(cacheDirectory: tempDir)
        let callCounter = ProviderCallCounter()

        let mockProvider = CountingMockVehicleRegistryProvider(counter: callCounter) { registration in
            VehicleSpecificationProfileBuilder.build(
                registrationMark: registration,
                vehicleClass: .heavyGoodsVehicle,
                make: "DAF",
                model: "XF",
                source: .verifiedAPI
            )
        }

        let coordinator = VehicleRegistryCoordinator(
            networkProviders: [mockProvider],
            cache: cache
        )

        _ = try await coordinator.resolveVehicle(registrationMark: "AB12CDE")
        _ = try await coordinator.resolveVehicle(registrationMark: "AB12CDE")

        #expect(callCounter.count == 1)
    }

    @Test func coordinator_networkSuccess_storesVerified() async throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let cache = VehicleSpecificationCache(cacheDirectory: tempDir)

        let mockProvider = MockVehicleRegistryProvider { registration in
            VehicleSpecificationProfileBuilder.build(
                registrationMark: registration,
                vehicleClass: .lightCommercialVehicle,
                make: "FORD",
                model: "TRANSIT",
                source: .verifiedAPI
            )
        }

        let coordinator = VehicleRegistryCoordinator(
            networkProviders: [mockProvider],
            cache: cache
        )

        _ = try await coordinator.resolveVehicle(registrationMark: "AB12CDE")
        let cached = await cache.profile(forKey: "AB12CDE")

        #expect(cached?.source == .verifiedAPI)
        #expect(cached?.make == "FORD")
    }

    @Test func coordinator_heuristicNotCached() async throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let cache = VehicleSpecificationCache(cacheDirectory: tempDir)

        let failingProvider = MockVehicleRegistryProvider { _ in
            throw VehicleRegistryError.networkFailure("offline")
        }

        let coordinator = VehicleRegistryCoordinator(
            networkProviders: [failingProvider],
            cache: cache
        )

        let profile = try await coordinator.resolveVehicle(registrationMark: "AB12CDE")
        let cached = await cache.profile(forKey: "AB12CDE")

        #expect(profile.source == .fallbackSynthesized)
        #expect(cached == nil)
    }

    @Test func coordinatorTagsHeuristicFallback() async throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let cache = VehicleSpecificationCache(cacheDirectory: tempDir)

        let failingProvider = MockVehicleRegistryProvider { _ in
            throw VehicleRegistryError.networkFailure("offline")
        }

        let coordinator = VehicleRegistryCoordinator(
            networkProviders: [failingProvider],
            cache: cache
        )
        let profile = try await coordinator.resolveVehicle(registrationMark: "AB12CDE")

        #expect(profile.source == .fallbackSynthesized)
    }

    @Test func manualClassOverride_preservesSource() async throws {
        let mockProvider = MockVehicleRegistryProvider { _ in
            VehicleSpecificationProfileBuilder.build(
                registrationMark: "AB12CDE",
                vehicleClass: .passengerCar,
                make: "FORD",
                model: "FOCUS",
                source: .verifiedAPI
            )
        }

        let coordinator = VehicleRegistryCoordinator(networkProviders: [mockProvider])
        let profile = try await coordinator.resolveVehicle(
            registrationMark: "AB12CDE",
            manualClassOverride: .heavyGoodsVehicle
        )

        #expect(profile.vehicleClass == .heavyGoodsVehicle)
        #expect(profile.source == .verifiedAPI)
    }
}

private struct MockVehicleRegistryProvider: VehicleRegistryProvider {
    private let handler: @Sendable (String) async throws -> VehicleSpecificationProfile

    init(handler: @escaping @Sendable (String) async throws -> VehicleSpecificationProfile) {
        self.handler = handler
    }

    func fetchSpecifications(for registrationMark: String) async throws -> VehicleSpecificationProfile {
        try await handler(registrationMark)
    }
}

private final class ProviderCallCounter: @unchecked Sendable {
    private(set) var count = 0

    func increment() {
        count += 1
    }
}

private struct CountingMockVehicleRegistryProvider: VehicleRegistryProvider {
    private let counter: ProviderCallCounter
    private let handler: @Sendable (String) async throws -> VehicleSpecificationProfile

    init(
        counter: ProviderCallCounter,
        handler: @escaping @Sendable (String) async throws -> VehicleSpecificationProfile
    ) {
        self.counter = counter
        self.handler = handler
    }

    func fetchSpecifications(for registrationMark: String) async throws -> VehicleSpecificationProfile {
        counter.increment()
        return try await handler(registrationMark)
    }
}
