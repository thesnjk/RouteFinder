import Contracts
import Foundation

/// DVLA Vehicle Enquiry Service (VES) JSON response.
public struct DVLAVehicleResponse: Sendable, Codable {
    public let registrationNumber: String?
    public let make: String?
    public let model: String?
    public let fuelType: String?
    public let co2Emissions: Int?
    public let euroStatus: String?
    public let revenueWeight: Int?
    public let typeApproval: String?
    public let wheelplan: String?
    public let artics: String?

    /// Creates a DVLA response from decoded JSON fields.
    public init(
        registrationNumber: String? = nil,
        make: String? = nil,
        model: String? = nil,
        fuelType: String? = nil,
        co2Emissions: Int? = nil,
        euroStatus: String? = nil,
        revenueWeight: Int? = nil,
        typeApproval: String? = nil,
        wheelplan: String? = nil,
        artics: String? = nil
    ) {
        self.registrationNumber = registrationNumber
        self.make = make
        self.model = model
        self.fuelType = fuelType
        self.co2Emissions = co2Emissions
        self.euroStatus = euroStatus
        self.revenueWeight = revenueWeight
        self.typeApproval = typeApproval
        self.wheelplan = wheelplan
        self.artics = artics
    }

    /// Maps DVLA fields to the shared registry profile used by routing and simulation.
    public func toRegistryProfile() -> VehicleRegistryProfile {
        let weightTonnes = Double(revenueWeight ?? 0) / 1000.0
        let isHGV = isHeavyGoodsVehicle
        let axleCount = inferredAxleCount

        if isHGV {
            let artic = VehicleProfile.ukArtic
            return VehicleRegistryProfile(
                vehicleType: .hgv,
                heightM: artic.height ?? 4.0,
                widthM: artic.width ?? 2.55,
                lengthM: artic.length ?? 16.5,
                weightTonnes: weightTonnes > 0 ? weightTonnes : (artic.weight ?? 44.0),
                axleCount: axleCount,
                enginePowerHP: weightTonnes >= 30 ? 500 : 380,
                isHGVMode: true,
                displayName: displayName,
                emissionClass: inferredEmissionClass
            )
        }

        return VehicleRegistryProfile(
            vehicleType: .passengerCar,
            heightM: 1.5,
            widthM: 1.8,
            lengthM: 4.5,
            weightTonnes: weightTonnes > 0 ? weightTonnes : 1.8,
            axleCount: axleCount,
            enginePowerHP: 150,
            isHGVMode: false,
            displayName: displayName,
            emissionClass: inferredEmissionClass
        )
    }

    private var displayName: String {
        let parts = [make, model].compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        return parts.isEmpty ? "Registered Vehicle" : parts.joined(separator: " ")
    }

    private var isHeavyGoodsVehicle: Bool {
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

    private var inferredAxleCount: Int {
        let combined = [wheelplan, artics, typeApproval]
            .compactMap { $0?.lowercased() }
            .joined(separator: " ")
        if combined.contains("6x2") || combined.contains("6 x 2") { return 6 }
        if combined.contains("6x4") || combined.contains("6 x 4") { return 6 }
        if combined.contains("8x4") || combined.contains("8 x 4") { return 8 }
        if combined.contains("artic") { return 6 }
        if combined.contains("rigid") { return 3 }
        return isHeavyGoodsVehicle ? 6 : 2
    }

    private var inferredEmissionClass: EmissionClass? {
        guard let euroStatus else { return nil }
        let normalized = euroStatus.lowercased()
        if normalized.contains("6") { return .euro6 }
        if normalized.contains("5") { return .euro5 }
        if normalized.contains("4") { return .euro4 }
        if normalized.contains("3") { return .euro3 }
        if normalized.contains("2") { return .euro2 }
        if normalized.contains("1") { return .euro1 }
        return nil
    }
}
