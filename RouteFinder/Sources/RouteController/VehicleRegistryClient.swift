import Contracts
import DataLayer
import Foundation

/// Async vehicle registration lookup with commercial registry providers and heuristic fallback.
public struct VehicleRegistryClient: Sendable {
    private let session: URLSession
    private let coordinator: VehicleRegistryCoordinator

    /// Creates a registry client using the default provider chain.
    public init(session: URLSession = SecureURLSession.shared) {
        self.session = session
        self.coordinator = VehicleRegistryCoordinator.makeDefault(session: session)
    }

    /// Creates a registry client with an explicit coordinator (for testing).
    public init(coordinator: VehicleRegistryCoordinator) {
        self.session = SecureURLSession.shared
        self.coordinator = coordinator
    }

    /// Rebuilds the provider chain after credential changes (e.g. RegCheck username saved in Settings).
    public func rebuildProviders(session: URLSession? = nil) -> VehicleRegistryClient {
        let activeSession = session ?? self.session
        return VehicleRegistryClient(session: activeSession)
    }

    /// Looks up a registration plate and returns a vehicle profile.
    public func lookup(
        registration: String,
        region: VehicleRegistryRegion = .auto,
        manualClassOverride: VehicleProfileClass? = nil
    ) async throws -> VehicleRegistryProfile {
        let spec = try await lookupSpecification(
            registration: registration,
            manualClassOverride: manualClassOverride
        )
        return resolvedRegistryProfile(
            from: spec,
            registration: registration,
            region: region
        )
    }
    public func lookupSpecification(
        registration: String,
        manualClassOverride: VehicleProfileClass? = nil
    ) async throws -> VehicleSpecificationProfile {
        let sanitized = RegistrationNormalizer.normalize(registration)
        guard !sanitized.isEmpty else {
            throw VehicleRegistryError.emptyRegistration
        }
        return try await coordinator.resolveVehicle(
            registrationMark: sanitized,
            manualClassOverride: manualClassOverride
        )
    }

    private func resolvedRegistryProfile(
        from spec: VehicleSpecificationProfile,
        registration: String,
        region: VehicleRegistryRegion
    ) -> VehicleRegistryProfile {
        let profile = spec.toRegistryProfile()

        let resolvedRegion = region == .auto
            ? RegionalPlateFallbackParser.detectRegion(from: registration)
            : region

        if shouldApplyRegionalFallback(spec: spec, region: resolvedRegion, registration: registration) {
            if let fallback = RegionalPlateFallbackParser.parse(registration: registration, region: resolvedRegion) {
                return fallback
            }
        }

        return profile
    }

    private func shouldApplyRegionalFallback(
        spec: VehicleSpecificationProfile,
        region: VehicleRegistryRegion,
        registration: String
    ) -> Bool {
        guard spec.vehicleClass == .passengerCar else { return false }
        guard spec.make == "Unknown", spec.model == "Unknown" else { return false }
        let normalized = registration.uppercased()
        return normalized.contains("TRUCK")
            || normalized.contains("HGV")
            || normalized.contains("LKW")
            || normalized.contains("SEMI")
            || normalized.contains("44T")
            || region != .uk
    }
}
