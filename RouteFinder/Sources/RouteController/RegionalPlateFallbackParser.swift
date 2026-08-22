import Contracts
import Foundation

/// Regex-driven fallback when live registry lookup is unavailable or the plate is non-UK.
public enum RegionalPlateFallbackParser {
    /// Parses a registration plate into a structural vehicle profile.
    public static func parse(registration: String, region: VehicleRegistryRegion) -> VehicleRegistryProfile? {
        let normalized = RegistrationNormalizer.normalize(registration)
        guard !normalized.isEmpty else { return nil }

        if let legacy = VehicleRegistryLookupService.legacyLookup(registration: normalized) {
            return legacy
        }

        let resolvedRegion = region == .auto ? detectRegion(from: normalized) : region

        switch resolvedRegion {
        case .uk:
            return parseUK(normalized)
        case .eu:
            return parseEU(normalized)
        case .us:
            return parseUS(normalized)
        case .auto:
            return nil
        }
    }

    /// Detects the most likely registry region from plate format.
    public static func detectRegion(from registration: String) -> VehicleRegistryRegion {
        let compact = RegistrationNormalizer.normalize(registration)
        if ukPlateRegex.firstMatch(in: compact) != nil { return .uk }
        if euPlateRegex.firstMatch(in: compact) != nil { return .eu }
        if usPlateRegex.firstMatch(in: compact) != nil { return .us }
        return .uk
    }

    /// Returns true when the plate matches UK format suitable for DVLA lookup.
    public static func isUKPlate(_ registration: String) -> Bool {
        let compact = RegistrationNormalizer.normalize(registration)
        return ukPlateRegex.firstMatch(in: compact) != nil
    }

    private static let ukPlateRegex = try! NSRegularExpression(pattern: "^[A-Z]{2}[0-9]{2}[A-Z]{3}$")
    private static let euPlateRegex = try! NSRegularExpression(pattern: "^[A-Z]{1,3}-?[A-Z]{0,2}[0-9]{1,4}[A-Z]{0,2}$")
    private static let usPlateRegex = try! NSRegularExpression(pattern: "^[A-Z0-9]{1,8}$")

    private static func parseUK(_ registration: String) -> VehicleRegistryProfile? {
        if registration.contains("TRUCK") || registration.contains("44T") || registration.contains("HGV") {
            let artic = VehicleProfile.ukArtic
            return VehicleRegistryProfile(
                vehicleType: .hgv,
                heightM: artic.height ?? 4.0,
                widthM: artic.width ?? 2.55,
                lengthM: artic.length ?? 16.5,
                weightTonnes: artic.weight ?? 44.0,
                axleCount: 6,
                enginePowerHP: 500,
                isHGVMode: true,
                displayName: "UK HGV (inferred)"
            )
        }

        return VehicleRegistryProfile(
            vehicleType: .passengerCar,
            heightM: 1.5,
            widthM: 1.8,
            lengthM: 4.5,
            weightTonnes: 1.8,
            axleCount: 2,
            enginePowerHP: 150,
            isHGVMode: false,
            displayName: "UK Vehicle (inferred)"
        )
    }

    private static func parseEU(_ registration: String) -> VehicleRegistryProfile? {
        if registration.contains("TRUCK") || registration.contains("LKW") || registration.contains("HGV") {
            return VehicleRegistryProfile(
                vehicleType: .hgv,
                heightM: 4.0,
                widthM: 2.55,
                lengthM: 13.6,
                weightTonnes: 40.0,
                axleCount: 5,
                enginePowerHP: 460,
                isHGVMode: true,
                displayName: "EU Commercial (inferred)"
            )
        }

        return VehicleRegistryProfile(
            vehicleType: .passengerCar,
            heightM: 1.48,
            widthM: 1.82,
            lengthM: 4.4,
            weightTonnes: 1.6,
            axleCount: 2,
            enginePowerHP: 130,
            isHGVMode: false,
            displayName: "EU Vehicle (inferred)"
        )
    }

    private static func parseUS(_ registration: String) -> VehicleRegistryProfile? {
        if registration.contains("TRUCK") || registration.contains("SEMI") {
            return VehicleRegistryProfile(
                vehicleType: .hgv,
                heightM: 4.11,
                widthM: 2.59,
                lengthM: 16.2,
                weightTonnes: 36.3,
                axleCount: 5,
                enginePowerHP: 480,
                isHGVMode: true,
                displayName: "US Truck (inferred)"
            )
        }

        return VehicleRegistryProfile(
            vehicleType: .passengerCar,
            heightM: 1.52,
            widthM: 1.85,
            lengthM: 4.8,
            weightTonnes: 2.0,
            axleCount: 2,
            enginePowerHP: 200,
            isHGVMode: false,
            displayName: "US Vehicle (inferred)"
        )
    }
}

private extension NSRegularExpression {
    func firstMatch(in string: String) -> NSTextCheckingResult? {
        let range = NSRange(string.startIndex..<string.endIndex, in: string)
        return firstMatch(in: string, range: range)
    }
}
