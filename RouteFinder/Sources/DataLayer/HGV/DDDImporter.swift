import Contracts
import Foundation

/// Errors raised while importing driver-card exports.
public enum TachoImportError: Error, Sendable, LocalizedError, Equatable {
    /// Binary DDD was not recognized and no JSON sidecar / fixture was available.
    case unrecognizedBinaryDDD
    /// Payload was not valid JSON for the advisory import schema.
    case invalidJSON
    /// JSON was present but required remaining-time keys were missing.
    case missingRequiredFields
    /// Partner remote tacho integration has not been configured.
    case partnerNotConfigured

    public var errorDescription: String? {
        switch self {
        case .unrecognizedBinaryDDD:
            return "Full binary DDD parse requires partner SDK; drop a JSON export with remainingDriveSeconds"
        case .invalidJSON:
            return "Could not parse tachograph export as JSON."
        case .missingRequiredFields:
            return "Tachograph JSON is missing required remaining drive fields."
        case .partnerNotConfigured:
            return "Partner tachograph integration is not configured."
        }
    }
}

/// Best-effort importer for driver-card DDD files and JSON remaining-time fixtures.
///
/// Real DDD is a complex binary format. This importer:
/// - Parses the simple JSON schema and text dumps with known keys
/// - Accepts a companion `.json` sidecar next to a binary `.ddd`
/// - Returns ``TachoImportError/unrecognizedBinaryDDD`` for opaque binaries
public struct DDDImporter: TachoCardImportPort, Sendable {
    private let clock: @Sendable () -> Date

    /// Creates an importer with an optional injectable clock (tests).
    public init(now: @escaping @Sendable () -> Date = { Date() }) {
        self.clock = now
    }

    /// Parses driver-card payload bytes (JSON fixture / text dump preferred).
    public func importDriverCard(data: Data) async throws -> TachoCardSummary {
        try importDriverCard(data: data, sourceFileName: "import", sidecarData: nil)
    }

    /// Parses payload bytes with an explicit source file name and optional sidecar JSON.
    public func importDriverCard(
        data: Data,
        sourceFileName: String,
        sidecarData: Data? = nil
    ) throws -> TachoCardSummary {
        if let summary = try? parseJSONExport(data, sourceFileName: sourceFileName) {
            return summary
        }
        if let summary = try? parseTextDump(data, sourceFileName: sourceFileName) {
            return summary
        }
        if let sidecarData,
           let summary = try? parseJSONExport(sidecarData, sourceFileName: sourceFileName) {
            return summary
        }
        if looksLikeBinary(data) {
            throw TachoImportError.unrecognizedBinaryDDD
        }
        // Last attempt: treat as JSON and surface a clearer error.
        try jsonFailure(for: data)
    }

    /// Loads a file URL, preferring a sibling `.json` sidecar when the primary file is binary DDD.
    public func importDriverCard(from url: URL) throws -> TachoCardSummary {
        let data = try Data(contentsOf: url)
        let sidecar = Self.sidecarJSONURL(for: url).flatMap { try? Data(contentsOf: $0) }
        return try importDriverCard(
            data: data,
            sourceFileName: url.lastPathComponent,
            sidecarData: sidecar
        )
    }

    // MARK: - Parsing

    private func parseJSONExport(_ data: Data, sourceFileName: String) throws -> TachoCardSummary {
        let object: Any
        do {
            object = try JSONSerialization.jsonObject(with: data)
        } catch {
            throw TachoImportError.invalidJSON
        }
        guard let dict = object as? [String: Any] else {
            throw TachoImportError.invalidJSON
        }
        return try summary(from: dict, sourceFileName: sourceFileName)
    }

    private func parseTextDump(_ data: Data, sourceFileName: String) throws -> TachoCardSummary {
        guard let text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) else {
            throw TachoImportError.invalidJSON
        }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !trimmed.hasPrefix("{") else {
            throw TachoImportError.invalidJSON
        }

        var values: [String: Any] = [:]
        for line in text.split(whereSeparator: \.isNewline) {
            let parts = line.split(separator: ":", maxSplits: 1).map {
                $0.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            guard parts.count == 2 else { continue }
            let key = parts[0]
            let raw = parts[1]
            if let number = Double(raw) {
                values[key] = number
            } else if !raw.isEmpty {
                values[key] = raw
            }
        }
        return try summary(from: values, sourceFileName: sourceFileName)
    }

    private func summary(from dict: [String: Any], sourceFileName: String) throws -> TachoCardSummary {
        let continuous = Self.number(
            in: dict,
            keys: [
                "remainingContinuousDriveSeconds",
                "remainingDriveSeconds",
                "continuousDriveRemainingSeconds",
            ]
        )
        let daily = Self.number(
            in: dict,
            keys: [
                "remainingDailyDriveSeconds",
                "dailyDriveRemainingSeconds",
            ]
        )
        let weekly = Self.number(
            in: dict,
            keys: [
                "remainingWeeklyDriveSeconds",
                "weeklyDriveRemainingSeconds",
            ]
        ) ?? continuous.map { _ in EU561HosClock.weeklyDriveLimitSeconds }

        guard let continuous, let daily, let weekly else {
            throw TachoImportError.missingRequiredFields
        }

        let cardNumber = Self.string(
            in: dict,
            keys: ["cardNumber", "driverCardNumber", "card_number"]
        )

        return TachoCardSummary(
            remainingContinuousDriveSeconds: continuous,
            remainingDailyDriveSeconds: daily,
            remainingWeeklyDriveSeconds: weekly,
            cardNumber: cardNumber,
            importedAt: clock(),
            sourceFileName: sourceFileName
        )
    }

    private func jsonFailure(for data: Data) throws -> Never {
        if (try? JSONSerialization.jsonObject(with: data)) != nil {
            throw TachoImportError.missingRequiredFields
        }
        throw TachoImportError.invalidJSON
    }

    private func looksLikeBinary(_ data: Data) -> Bool {
        guard !data.isEmpty else { return false }
        if String(data: data, encoding: .utf8) != nil {
            let prefix = data.prefix(1)
            if prefix == Data("{".utf8) || prefix == Data("[".utf8) {
                return false
            }
            // Printable text dump — not treated as opaque binary.
            let sample = data.prefix(256)
            let nonPrintable = sample.filter { byte in
                !(0x09...0x0D).contains(byte) && !(0x20...0x7E).contains(byte)
            }.count
            return Double(nonPrintable) / Double(max(sample.count, 1)) > 0.2
        }
        return true
    }

    private static func sidecarJSONURL(for url: URL) -> URL? {
        let base = url.deletingPathExtension().lastPathComponent
        let sibling = url.deletingLastPathComponent()
            .appendingPathComponent(base)
            .appendingPathExtension("json")
        guard sibling != url, FileManager.default.fileExists(atPath: sibling.path) else {
            return nil
        }
        return sibling
    }

    private static func number(in dict: [String: Any], keys: [String]) -> Double? {
        for key in keys {
            if let value = dict[key] as? Double { return value }
            if let value = dict[key] as? Int { return Double(value) }
            if let value = dict[key] as? NSNumber { return value.doubleValue }
            if let value = dict[key] as? String, let parsed = Double(value) { return parsed }
        }
        return nil
    }

    private static func string(in dict: [String: Any], keys: [String]) -> String? {
        for key in keys {
            if let value = dict[key] as? String {
                let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty { return trimmed }
            }
        }
        return nil
    }
}

/// Stub partner port that always reports not configured (VDO / Stoneridge / Samsara later).
public struct StubPartnerTachoPort: PartnerTachoPort, Sendable {
    /// Creates an unconfigured partner stub.
    public init() {}

    /// Always throws ``TachoImportError/partnerNotConfigured``.
    public func fetchRemoteStatus() async throws -> TachoCardSummary {
        throw TachoImportError.partnerNotConfigured
    }
}
