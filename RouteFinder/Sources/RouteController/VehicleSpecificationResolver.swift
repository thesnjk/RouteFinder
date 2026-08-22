import Contracts
import CoreLocation
import DataLayer
import Foundation

// MARK: - Domain Models

/// Commercial vehicle scale classification for kinetic physics and routing.
public enum VehicleProfileClass: String, Codable, Sendable, Hashable, CaseIterable {
    case heavyGoodsVehicle = "HGV"
    case lightCommercialVehicle = "LCV"
    case passengerCar = "Car"

    /// Human-readable label for UI pickers.
    public var displayName: String {
        switch self {
        case .heavyGoodsVehicle: return "Heavy Goods Vehicle"
        case .lightCommercialVehicle: return "Light Commercial Vehicle"
        case .passengerCar: return "Passenger Car"
        }
    }
}

/// Provenance of a resolved vehicle specification profile.
public enum RegistrySource: String, Codable, Sendable, Equatable {
    case verifiedAPI
    case fallbackSynthesized
    case unverified
    case transientHeuristic
}

/// Resolved vehicle characteristics in SI units for physics and map footprint rendering.
public struct VehicleSpecificationProfile: Codable, Sendable, Equatable {
    public let registrationMark: String
    public let vehicleClass: VehicleProfileClass
    public let make: String
    public let model: String
    public let grossWeightKilograms: Double
    public let lengthMeters: Double
    public let widthMeters: Double
    public let heightMeters: Double
    public let axleCount: Int
    public let enginePowerHorsepower: Int?
    public let wheelbaseMeters: Double
    public let source: RegistrySource

    /// Creates a vehicle specification profile with SI dimensions.
    public init(
        registrationMark: String,
        vehicleClass: VehicleProfileClass,
        make: String,
        model: String,
        grossWeightKilograms: Double,
        lengthMeters: Double,
        widthMeters: Double,
        heightMeters: Double,
        axleCount: Int,
        enginePowerHorsepower: Int? = nil,
        wheelbaseMeters: Double? = nil,
        source: RegistrySource
    ) {
        self.registrationMark = registrationMark
        self.vehicleClass = vehicleClass
        self.make = make
        self.model = model
        self.grossWeightKilograms = grossWeightKilograms
        self.lengthMeters = lengthMeters
        self.widthMeters = widthMeters
        self.heightMeters = heightMeters
        self.axleCount = axleCount
        self.enginePowerHorsepower = enginePowerHorsepower
        self.wheelbaseMeters = wheelbaseMeters ?? vehicleClass.defaultWheelbaseMeters
        self.source = source
    }

    enum CodingKeys: String, CodingKey {
        case registrationMark
        case vehicleClass
        case make
        case model
        case grossWeightKilograms
        case lengthMeters
        case widthMeters
        case heightMeters
        case axleCount
        case enginePowerHorsepower
        case wheelbaseMeters
        case source
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        registrationMark = try container.decode(String.self, forKey: .registrationMark)
        vehicleClass = try container.decode(VehicleProfileClass.self, forKey: .vehicleClass)
        make = try container.decode(String.self, forKey: .make)
        model = try container.decode(String.self, forKey: .model)
        grossWeightKilograms = try container.decode(Double.self, forKey: .grossWeightKilograms)
        lengthMeters = try container.decode(Double.self, forKey: .lengthMeters)
        widthMeters = try container.decode(Double.self, forKey: .widthMeters)
        heightMeters = try container.decode(Double.self, forKey: .heightMeters)
        axleCount = try container.decode(Int.self, forKey: .axleCount)
        enginePowerHorsepower = try container.decodeIfPresent(Int.self, forKey: .enginePowerHorsepower)
        wheelbaseMeters = try container.decodeIfPresent(Double.self, forKey: .wheelbaseMeters)
            ?? vehicleClass.defaultWheelbaseMeters
        source = try container.decode(RegistrySource.self, forKey: .source)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(registrationMark, forKey: .registrationMark)
        try container.encode(vehicleClass, forKey: .vehicleClass)
        try container.encode(make, forKey: .make)
        try container.encode(model, forKey: .model)
        try container.encode(grossWeightKilograms, forKey: .grossWeightKilograms)
        try container.encode(lengthMeters, forKey: .lengthMeters)
        try container.encode(widthMeters, forKey: .widthMeters)
        try container.encode(heightMeters, forKey: .heightMeters)
        try container.encode(axleCount, forKey: .axleCount)
        try container.encodeIfPresent(enginePowerHorsepower, forKey: .enginePowerHorsepower)
        try container.encode(wheelbaseMeters, forKey: .wheelbaseMeters)
        try container.encode(source, forKey: .source)
    }

    /// Builds an oriented footprint polygon in WGS84 for map visualization.
    public func orientedFootprint(
        center: CLLocationCoordinate2D,
        bearingDegrees: Double
    ) -> [CLLocationCoordinate2D] {
        VehicleSpatialExtent(
            lengthMeters: lengthMeters,
            widthMeters: widthMeters
        ).orientedFootprint(center: center, bearingDegrees: bearingDegrees)
    }

    /// Returns true when the profile represents a commercial heavy goods vehicle.
    public var isCommercialHGV: Bool {
        vehicleClass == .heavyGoodsVehicle
    }

}

/// Type-safe cache envelope that tracks vehicle profile age for TTL expiration.
public struct CachedVehicleProfile: Codable, Sendable {
    public let profile: VehicleSpecificationProfile
    public let cachedAt: Date

    /// Creates a cached vehicle profile envelope.
    public init(profile: VehicleSpecificationProfile, cachedAt: Date) {
        self.profile = profile
        self.cachedAt = cachedAt
    }

    public var isExpired: Bool {
        // Enforce a strict 30-day Time-To-Live (TTL) to balance data accuracy with API cost controls
        let thirtyDaysInSeconds: TimeInterval = 30 * 24 * 60 * 60
        return Date().timeIntervalSince(cachedAt) > thirtyDaysInSeconds
    }
}

/// SI bounding dimensions used for georeferenced footprint generation.
public struct VehicleSpatialExtent: Sendable, Equatable {
    public let lengthMeters: Double
    public let widthMeters: Double

    /// Builds a closed polygon for an oriented vehicle rectangle in WGS84.
    ///
    /// The footprint is rear-axle anchored: the supplied center is treated as the vehicle
    /// geometric center and projected backward by half the length before corner generation.
    public func orientedFootprint(
        center: CLLocationCoordinate2D,
        bearingDegrees: Double
    ) -> [CLLocationCoordinate2D] {
        let rearAxle = VehicleGeometryCalculator.offsetBackward(
            from: center,
            bearingDegrees: bearingDegrees,
            backwardMeters: lengthMeters / 2.0
        )
        return VehicleGeometryCalculator.generateFootprint(
            rearAxle: rearAxle,
            headingDegrees: bearingDegrees,
            lengthMeters: lengthMeters,
            widthMeters: widthMeters
        )
    }
}

// MARK: - Canonical Dimensions

/// Physical template for a vehicle profile class.
public struct VehicleClassDimensions: Sendable, Equatable {
    public let grossWeightKilograms: Double
    public let lengthMeters: Double
    public let widthMeters: Double
    public let heightMeters: Double
    public let axleCount: Int
}

/// Class-specific physics defaults for routing constraints and simulation.
public struct VehiclePhysicsDefaults: Sendable, Equatable {
    /// Minimum turning radius in meters.
    public let turningRadiusMeters: Double
    /// Per-axle weight in tonnes.
    public let axleWeightTonnes: Double
    /// Ground clearance in meters.
    public let groundClearanceMeters: Double

    /// Creates physics defaults for a vehicle class.
    public init(
        turningRadiusMeters: Double,
        axleWeightTonnes: Double,
        groundClearanceMeters: Double
    ) {
        self.turningRadiusMeters = turningRadiusMeters
        self.axleWeightTonnes = axleWeightTonnes
        self.groundClearanceMeters = groundClearanceMeters
    }

    /// Returns class-specific physics defaults.
    public static func forClass(_ vehicleClass: VehicleProfileClass) -> VehiclePhysicsDefaults {
        switch vehicleClass {
        case .passengerCar:
            return VehiclePhysicsDefaults(
                turningRadiusMeters: 5.0,
                axleWeightTonnes: 0.75,
                groundClearanceMeters: 0.15
            )
        case .lightCommercialVehicle:
            return VehiclePhysicsDefaults(
                turningRadiusMeters: 7.0,
                axleWeightTonnes: 1.75,
                groundClearanceMeters: 0.20
            )
        case .heavyGoodsVehicle:
            return VehiclePhysicsDefaults(
                turningRadiusMeters: 12.5,
                axleWeightTonnes: 6.0,
                groundClearanceMeters: 0.35
            )
        }
    }

    /// Estimates axle weight from gross weight and axle count when registry data is available.
    public static func estimatedAxleWeightTonnes(
        grossWeightKilograms: Double,
        axleCount: Int,
        vehicleClass: VehicleProfileClass
    ) -> Double {
        guard grossWeightKilograms > 0, axleCount > 0 else {
            return forClass(vehicleClass).axleWeightTonnes
        }
        let tonnes = grossWeightKilograms / 1000.0
        return max(tonnes / Double(axleCount), forClass(vehicleClass).axleWeightTonnes * 0.5)
    }
}

/// Resolved physics values after applying user overrides and class defaults.
public struct ResolvedVehiclePhysics: Sendable, Equatable {
    public let turningRadiusMeters: Double
    public let axleWeightTonnes: Double
    public let groundClearanceMeters: Double

    /// Creates resolved physics values.
    public init(
        turningRadiusMeters: Double,
        axleWeightTonnes: Double,
        groundClearanceMeters: Double
    ) {
        self.turningRadiusMeters = turningRadiusMeters
        self.axleWeightTonnes = axleWeightTonnes
        self.groundClearanceMeters = groundClearanceMeters
    }

    /// Resolves physics fields from user input, registry specification, and class defaults.
    public static func resolved(
        vehicleClass: VehicleProfileClass,
        userOverrides: VehicleProfile,
        specification: VehicleSpecificationProfile?
    ) -> ResolvedVehiclePhysics {
        let defaults = VehiclePhysicsDefaults.forClass(vehicleClass)
        let registryAxleWeight: Double?
        if let specification, specification.grossWeightKilograms > 0, specification.axleCount > 0 {
            registryAxleWeight = VehiclePhysicsDefaults.estimatedAxleWeightTonnes(
                grossWeightKilograms: specification.grossWeightKilograms,
                axleCount: specification.axleCount,
                vehicleClass: vehicleClass
            )
        } else {
            registryAxleWeight = nil
        }

        return ResolvedVehiclePhysics(
            turningRadiusMeters: userOverrides.turningRadius ?? defaults.turningRadiusMeters,
            axleWeightTonnes: userOverrides.axleWeight ?? registryAxleWeight ?? defaults.axleWeightTonnes,
            groundClearanceMeters: userOverrides.groundClearance ?? defaults.groundClearanceMeters
        )
    }
}

extension VehicleProfileClass {
    /// Default wheelbase distance in meters for Ackermann steering kinematics.
    public var defaultWheelbaseMeters: Double {
        switch self {
        case .heavyGoodsVehicle:
            return 6.5
        case .passengerCar:
            return 2.7
        case .lightCommercialVehicle:
            return 3.5
        }
    }

    /// Conservative, dimensionally accurate constraints for each vehicle class.
    public var canonicalDimensions: VehicleClassDimensions {
        switch self {
        case .heavyGoodsVehicle:
            return VehicleClassDimensions(
                grossWeightKilograms: 18_000,
                lengthMeters: 12.0,
                widthMeters: 2.55,
                heightMeters: 4.0,
                axleCount: 3
            )
        case .lightCommercialVehicle:
            return VehicleClassDimensions(
                grossWeightKilograms: 3_500,
                lengthMeters: 6.0,
                widthMeters: 2.0,
                heightMeters: 2.5,
                axleCount: 2
            )
        case .passengerCar:
            return VehicleClassDimensions(
                grossWeightKilograms: 1_600,
                lengthMeters: 4.5,
                widthMeters: 1.8,
                heightMeters: 1.4,
                axleCount: 2
            )
        }
    }
}

// MARK: - Provider Protocol

/// Asynchronous vehicle registry lookup abstraction.
public protocol VehicleRegistryProvider: Sendable {
    /// Fetches vehicle specifications for a normalized registration mark.
    func fetchSpecifications(for registrationMark: String) async throws -> VehicleSpecificationProfile
}

// MARK: - Keyword Classifier

enum VehicleProfileClassifier {
    private static let heavyCommercialKeywords = [
        "DAF",
        "SCANIA",
        "MERCEDES-BENZ ACTROS",
        "MAN",
        "IVECO",
    ]

    private static let volvoHGVModelTokens = [
        "FH", "FM", "FE", "FL", "FMX", "VN", "VNL",
    ]

    private static let passengerBodyStyleKeywords = [
        "HATCHBACK", "SALOON", "ESTATE", "SUV", "COUPE", "MPV",
        "CROSSOVER", "CONVERTIBLE", "ROADSTER", "HATCH", "SEDAN",
    ]

    private static let lightCommercialKeywords = [
        "TRANSIT",
        "SPRINTER",
        "VIVARO",
        "CRAFTER",
        "DUCATO",
    ]

    static func isPassengerBodyStyle(_ bodyStyle: String?) -> Bool {
        guard let bodyStyle else { return false }
        let uppercased = bodyStyle.uppercased()
        return passengerBodyStyleKeywords.contains { uppercased.contains($0) }
    }

    static func classifyVolvoCommercial(from corpus: String) -> VehicleProfileClass? {
        let uppercased = corpus.uppercased()
        guard matchesKeyword("VOLVO", in: uppercased, useWordBoundaries: true) else {
            return nil
        }
        for token in volvoHGVModelTokens where matchesKeyword(token, in: uppercased, useWordBoundaries: false) {
            return .heavyGoodsVehicle
        }
        return nil
    }

    static func classify(
        from corpus: String,
        grossWeightKilograms: Double? = nil,
        bodyStyle: String? = nil,
        useWordBoundaries: Bool = true
    ) -> VehicleProfileClass {
        if isPassengerBodyStyle(bodyStyle) {
            return .passengerCar
        }

        let uppercased = corpus.uppercased()

        if let volvoClass = classifyVolvoCommercial(from: corpus) {
            return volvoClass
        }

        for keyword in heavyCommercialKeywords where matchesKeyword(keyword, in: uppercased, useWordBoundaries: useWordBoundaries) {
            return .heavyGoodsVehicle
        }

        for keyword in lightCommercialKeywords where matchesKeyword(keyword, in: uppercased, useWordBoundaries: useWordBoundaries) {
            return .lightCommercialVehicle
        }

        if let grossWeightKilograms {
            if grossWeightKilograms >= 7_500 {
                return .heavyGoodsVehicle
            }
            if grossWeightKilograms >= 2_500 {
                return .lightCommercialVehicle
            }
        }

        return .passengerCar
    }

    private static func matchesKeyword(_ keyword: String, in corpus: String, useWordBoundaries: Bool) -> Bool {
        if keyword.contains(" ") {
            return corpus.contains(keyword)
        }
        if !useWordBoundaries {
            return corpus.contains(keyword)
        }
        let escaped = NSRegularExpression.escapedPattern(for: keyword)
        let pattern = "\\b\(escaped)\\b"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return corpus.contains(keyword)
        }
        let range = NSRange(corpus.startIndex..<corpus.endIndex, in: corpus)
        return regex.firstMatch(in: corpus, options: [], range: range) != nil
    }

    static func parseWeightKilograms(from raw: String?) -> Double? {
        guard let raw else { return nil }
        let digits = raw.filter { $0.isNumber }
        guard let value = Double(digits), value > 0 else { return nil }
        if value > 100_000 {
            return nil
        }
        return value
    }

    static func parseHeightMeters(from raw: String?) -> Double? {
        parseDimensionMeters(from: raw, maxMeters: 10.0)
    }

    static func parseDimensionMeters(from raw: String?, maxMeters: Double) -> Double? {
        guard let raw else { return nil }
        let normalized = raw
            .replacingOccurrences(of: ",", with: ".")
            .filter { $0.isNumber || $0 == "." }
        guard let value = Double(normalized), value > 0 else { return nil }
        if value > maxMeters {
            return value / 1000.0
        }
        return value
    }
}

// MARK: - Profile Builder

enum VehicleSpecificationProfileBuilder {
    private static let lengthBoundsMeters = 2.0...16.0
    private static let widthBoundsMeters = 1.4...2.6
    private static let wheelbaseBoundsMeters = 2.0...7.0

    static func build(
        registrationMark: String,
        vehicleClass: VehicleProfileClass,
        make: String,
        model: String,
        grossWeightKilograms: Double? = nil,
        heightMeters: Double? = nil,
        enginePowerHorsepower: Int? = nil,
        lengthMetersOverride: Double? = nil,
        widthMetersOverride: Double? = nil,
        wheelbaseMetersOverride: Double? = nil,
        source: RegistrySource = .transientHeuristic
    ) -> VehicleSpecificationProfile {
        let template = vehicleClass.canonicalDimensions
        let resolvedWeight = grossWeightKilograms.flatMap { $0 > 0 ? $0 : nil } ?? template.grossWeightKilograms
        let resolvedHeight = heightMeters.flatMap { $0 > 0 ? $0 : nil } ?? template.heightMeters
        let resolvedLength = clampedDimension(lengthMetersOverride, fallback: template.lengthMeters, bounds: lengthBoundsMeters)
        let resolvedWidth = clampedDimension(widthMetersOverride, fallback: template.widthMeters, bounds: widthBoundsMeters)
        let resolvedWheelbase = clampedDimension(
            wheelbaseMetersOverride,
            fallback: vehicleClass.defaultWheelbaseMeters,
            bounds: wheelbaseBoundsMeters
        )

        return VehicleSpecificationProfile(
            registrationMark: registrationMark,
            vehicleClass: vehicleClass,
            make: make,
            model: model,
            grossWeightKilograms: resolvedWeight,
            lengthMeters: resolvedLength,
            widthMeters: resolvedWidth,
            heightMeters: resolvedHeight,
            axleCount: template.axleCount,
            enginePowerHorsepower: enginePowerHorsepower,
            wheelbaseMeters: resolvedWheelbase,
            source: source
        )
    }

    private static func clampedDimension(
        _ value: Double?,
        fallback: Double,
        bounds: ClosedRange<Double>
    ) -> Double {
        guard let value, value > 0 else { return fallback }
        return min(max(value, bounds.lowerBound), bounds.upperBound)
    }

    static func applyClassOverride(
        _ override: VehicleProfileClass,
        to profile: VehicleSpecificationProfile
    ) -> VehicleSpecificationProfile {
        let template = override.canonicalDimensions
        return VehicleSpecificationProfile(
            registrationMark: profile.registrationMark,
            vehicleClass: override,
            make: profile.make,
            model: profile.model,
            grossWeightKilograms: template.grossWeightKilograms,
            lengthMeters: template.lengthMeters,
            widthMeters: template.widthMeters,
            heightMeters: template.heightMeters,
            axleCount: template.axleCount,
            enginePowerHorsepower: profile.enginePowerHorsepower,
            wheelbaseMeters: override.defaultWheelbaseMeters,
            source: profile.source
        )
    }
}

// MARK: - Adapter to VehicleRegistryProfile

extension VehicleSpecificationProfile {
    /// Maps SI specification profile to the shared registry profile used by routing and simulation.
    public func toRegistryProfile() -> VehicleRegistryProfile {
        let weightTonnes = grossWeightKilograms / 1000.0
        let isCommercial = vehicleClass != .passengerCar

        return VehicleRegistryProfile(
            vehicleType: isCommercial ? .hgv : .passengerCar,
            heightM: heightMeters,
            widthM: widthMeters,
            lengthM: lengthMeters,
            weightTonnes: weightTonnes,
            axleCount: axleCount,
            enginePowerHP: enginePowerHorsepower.map(Double.init) ?? inferredEnginePowerHP,
            isHGVMode: isCommercial,
            displayName: displayName,
            emissionClass: nil,
            registrySource: source
        )
    }

    private var displayName: String {
        let parts = [make, model]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && $0 != "Unknown" }
        if parts.isEmpty {
            return vehicleClass.displayName
        }
        return parts.joined(separator: " ")
    }

    private var inferredEnginePowerHP: Double {
        switch vehicleClass {
        case .heavyGoodsVehicle:
            return grossWeightKilograms >= 30_000 ? 500 : 380
        case .lightCommercialVehicle:
            return 150
        case .passengerCar:
            return 150
        }
    }
}

// MARK: - Heuristic Fallback

/// Deterministic local profile synthesizer when network providers fail.
public struct HeuristicSpecificationSynthesizer: VehicleRegistryProvider {
    public init() {}

    public func fetchSpecifications(for registrationMark: String) async throws -> VehicleSpecificationProfile {
        let normalized = RegistrationNormalizer.normalize(registrationMark)
        guard !normalized.isEmpty else {
            throw VehicleRegistryError.emptyRegistration
        }

        let vehicleClass = VehicleProfileClassifier.classify(from: normalized, useWordBoundaries: false)
        return VehicleSpecificationProfileBuilder.build(
            registrationMark: normalized,
            vehicleClass: vehicleClass,
            make: "Unknown",
            model: "Unknown",
            source: .fallbackSynthesized
        )
    }
}

// MARK: - DVLA Secondary Provider

/// Optional secondary provider wrapping the UK DVLA Vehicle Enquiry Service.
public struct DVLAVehicleRegistryProvider: VehicleRegistryProvider {
    private let apiKey: String
    private let session: URLSession

    /// Creates a DVLA registry provider with the given API key.
    public init(apiKey: String, session: URLSession = SecureURLSession.shared) throws {
        let trimmed = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw VehicleRegistryError.notConfigured
        }
        self.apiKey = trimmed
        self.session = session
    }

    public func fetchSpecifications(for registrationMark: String) async throws -> VehicleSpecificationProfile {
        let normalized = RegistrationNormalizer.normalize(registrationMark)
        guard !normalized.isEmpty else {
            throw VehicleRegistryError.emptyRegistration
        }

        let engine = try DVLAVehicleEnquiryEngine(apiKey: apiKey, session: session)
        let response = try await engine.lookup(registration: normalized)
        return response.toSpecificationProfile(registrationMark: normalized)
    }
}

extension DVLAVehicleResponse {
    func toSpecificationProfile(registrationMark: String) -> VehicleSpecificationProfile {
        let vehicleClass: VehicleProfileClass = isHeavyGoodsVehicleForSpecification
            ? .heavyGoodsVehicle
            : .passengerCar

        let grossWeight: Double? = {
            guard let revenueWeight, revenueWeight > 0 else { return nil }
            return Double(revenueWeight)
        }()

        let makeValue = make?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty ?? "Unknown"
        let modelValue = model?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty ?? "Unknown"

        return VehicleSpecificationProfileBuilder.build(
            registrationMark: registrationMark,
            vehicleClass: vehicleClass,
            make: makeValue,
            model: modelValue,
            grossWeightKilograms: grossWeight,
            source: .verifiedAPI
        )
    }

    private var isHeavyGoodsVehicleForSpecification: Bool {
        if let revenueWeight, revenueWeight >= 3500 { return true }
        let combined = [typeApproval, wheelplan, artics, fuelType]
            .compactMap { $0?.lowercased() }
            .joined(separator: " ")
        return combined.contains("artic")
            || combined.contains("hgv")
            || combined.contains("goods")
            || combined.contains("truck")
            || combined.contains("lorry")
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}

// MARK: - Coordinator

/// Thread-safe orchestration coordinator for vehicle specification resolution.
public actor VehicleRegistryCoordinator {
    private static let networkTimeoutNanoseconds: UInt64 = 3_500_000_000

    private let networkProviders: [any VehicleRegistryProvider]
    private let heuristicProvider: HeuristicSpecificationSynthesizer
    private let cache: VehicleSpecificationCache

    /// Creates a coordinator with explicit network providers and heuristic fallback.
    public init(
        networkProviders: [any VehicleRegistryProvider],
        heuristicProvider: HeuristicSpecificationSynthesizer = HeuristicSpecificationSynthesizer(),
        cache: VehicleSpecificationCache = VehicleSpecificationCache()
    ) {
        self.networkProviders = networkProviders
        self.heuristicProvider = heuristicProvider
        self.cache = cache
    }

    /// Builds the default provider chain: RegCheck, optional DVLA, then heuristic fallback.
    public static func makeDefault(session: URLSession = SecureURLSession.shared) -> VehicleRegistryCoordinator {
        var providers: [any VehicleRegistryProvider] = []

        if let regCheck = try? RegCheckRegistryProvider(session: session) {
            providers.append(regCheck)
        }

        if let dvlaKey = VehicleProfileStore.loadDVLAAPIKey(),
           !dvlaKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           let dvlaProvider = try? DVLAVehicleRegistryProvider(apiKey: dvlaKey, session: session) {
            providers.append(dvlaProvider)
        }

        return VehicleRegistryCoordinator(networkProviders: providers)
    }

    /// Resolves vehicle specifications with network providers, timeout, and heuristic fallback.
    public func resolveVehicle(
        registrationMark: String,
        manualClassOverride: VehicleProfileClass? = nil
    ) async throws -> VehicleSpecificationProfile {
        let sanitizedMark = RegistrationNormalizer.normalize(registrationMark)
        guard !sanitizedMark.isEmpty else {
            throw VehicleRegistryError.emptyRegistration
        }

        let resolved = await resolveFromProviders(registrationMark: sanitizedMark)

        if let manualClassOverride {
            return VehicleSpecificationProfileBuilder.applyClassOverride(manualClassOverride, to: resolved)
        }
        return resolved
    }

    private func resolveFromProviders(registrationMark: String) async -> VehicleSpecificationProfile {
        let cacheKey = VehicleSpecificationCache.cacheKey(for: registrationMark)

        if let cached = await cache.profile(forKey: cacheKey) {
            return cached
        }

        for provider in networkProviders {
            if let profile = await fetchWithTimeout(provider: provider, registrationMark: registrationMark) {
                await cache.store(profile, forKey: cacheKey)
                return profile
            }
        }

        if let heuristic = try? await heuristicProvider.fetchSpecifications(for: registrationMark) {
            return heuristic
        }

        return defaultPassengerProfile(registrationMark: registrationMark)
    }

    private func fetchWithTimeout(
        provider: any VehicleRegistryProvider,
        registrationMark: String
    ) async -> VehicleSpecificationProfile? {
        do {
            return try await withThrowingTaskGroup(of: VehicleSpecificationProfile.self) { group in
                group.addTask {
                    try await provider.fetchSpecifications(for: registrationMark)
                }
                group.addTask {
                    try await Task.sleep(nanoseconds: Self.networkTimeoutNanoseconds)
                    throw VehicleRegistryCoordinatorTimeout()
                }
                defer { group.cancelAll() }
                guard let profile = try await group.next() else {
                    throw VehicleRegistryCoordinatorTimeout()
                }
                return profile
            }
        } catch let error as VehicleRegistryError {
            print("[VehicleRegistry] Provider failed: \(error.localizedDescription)")
            return nil
        } catch {
            print("[VehicleRegistry] Provider failed: \(error.localizedDescription)")
            return nil
        }
    }

    private struct VehicleRegistryCoordinatorTimeout: Error {}

    private func defaultPassengerProfile(registrationMark: String) -> VehicleSpecificationProfile {
        VehicleSpecificationProfileBuilder.build(
            registrationMark: registrationMark,
            vehicleClass: .passengerCar,
            make: "Unknown",
            model: "Unknown",
            source: .unverified
        )
    }
}
