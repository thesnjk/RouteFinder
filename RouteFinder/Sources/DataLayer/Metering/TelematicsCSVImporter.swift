import Contracts
import Foundation

/// Errors from telematics CSV import.
public enum TelematicsCSVImporterError: Error, Sendable, LocalizedError {
    case emptyFile
    case missingRequiredColumns
    case noValidRows

    public var errorDescription: String? {
        switch self {
        case .emptyFile: return "Telematics CSV is empty."
        case .missingRequiredColumns: return "CSV needs latitude, longitude, and a vehicle/device column."
        case .noValidRows: return "No valid telematics rows found in CSV."
        }
    }
}

/// Tolerant CSV importer for Geotab / Samsara-style vehicle position exports (read-only).
public enum TelematicsCSVImporter: Sendable {
    /// Parses CSV text into vehicle pings.
    public static func parse(
        csv: String,
        defaultProvider: TelematicsProvider = .unknown
    ) throws -> [TelematicsVehiclePing] {
        let lines = csv
            .split(whereSeparator: \.isNewline)
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard let headerLine = lines.first else { throw TelematicsCSVImporterError.emptyFile }

        let headers = splitCSVLine(headerLine).map { normalizeHeader($0) }
        guard let latIndex = index(of: ["latitude", "lat", "y"], in: headers),
              let lonIndex = index(of: ["longitude", "lon", "lng", "long", "x"], in: headers),
              let labelIndex = index(
                of: ["vehicle", "vehicle name", "device", "device name", "name", "asset", "unit"],
                in: headers
              ) else {
            throw TelematicsCSVImporterError.missingRequiredColumns
        }

        let timeIndex = index(
            of: ["datetime", "timestamp", "date", "time", "recordedat", "gps time", "date/time"],
            in: headers
        )
        let speedIndex = index(of: ["speed", "speedkph", "speed_kmh", "speedkmh"], in: headers)
        let providerIndex = index(of: ["provider", "source", "telematics"], in: headers)

        var pings: [TelematicsVehiclePing] = []
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let isoBasic = ISO8601DateFormatter()

        for line in lines.dropFirst() {
            let cols = splitCSVLine(line)
            guard latIndex < cols.count, lonIndex < cols.count, labelIndex < cols.count,
                  let lat = Double(cols[latIndex].trimmingCharacters(in: .whitespaces)),
                  let lon = Double(cols[lonIndex].trimmingCharacters(in: .whitespaces)) else {
                continue
            }
            let label = cols[labelIndex].trimmingCharacters(in: .whitespacesAndNewlines)
            guard !label.isEmpty else { continue }

            var recordedAt = Date()
            if let timeIndex, timeIndex < cols.count {
                let raw = cols[timeIndex].trimmingCharacters(in: .whitespacesAndNewlines)
                if let parsed = iso.date(from: raw) ?? isoBasic.date(from: raw) {
                    recordedAt = parsed
                }
            }

            var speed: Double?
            if let speedIndex, speedIndex < cols.count {
                speed = Double(cols[speedIndex].trimmingCharacters(in: .whitespaces))
            }

            var provider = defaultProvider
            if let providerIndex, providerIndex < cols.count {
                let raw = cols[providerIndex].trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                if raw.contains("geotab") {
                    provider = .geotab
                } else if raw.contains("samsara") {
                    provider = .samsara
                }
            }

            pings.append(
                TelematicsVehiclePing(
                    provider: provider,
                    vehicleLabel: label,
                    latitude: lat,
                    longitude: lon,
                    recordedAt: recordedAt,
                    speedKph: speed
                )
            )
        }

        guard !pings.isEmpty else { throw TelematicsCSVImporterError.noValidRows }
        return pings
    }

    /// Parses CSV data and wraps a batch.
    public static func parseBatch(
        data: Data,
        sourceFileName: String? = nil,
        defaultProvider: TelematicsProvider = .unknown
    ) throws -> TelematicsImportBatch {
        guard let text = String(data: data, encoding: .utf8)
            ?? String(data: data, encoding: .isoLatin1) else {
            throw TelematicsCSVImporterError.emptyFile
        }
        let pings = try parse(csv: text, defaultProvider: defaultProvider)
        return TelematicsImportBatch(pings: pings, sourceFileName: sourceFileName)
    }

    private static func normalizeHeader(_ raw: String) -> String {
        raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "\""))
            .lowercased()
    }

    private static func index(of aliases: [String], in headers: [String]) -> Int? {
        for (i, header) in headers.enumerated() {
            if aliases.contains(header) { return i }
        }
        return nil
    }

    private static func splitCSVLine(_ line: String) -> [String] {
        var fields: [String] = []
        var current = ""
        var inQuotes = false
        for char in line {
            if char == "\"" {
                inQuotes.toggle()
                continue
            }
            if char == ",", !inQuotes {
                fields.append(current)
                current = ""
                continue
            }
            current.append(char)
        }
        fields.append(current)
        return fields
    }
}

/// Disk persistence for the last telematics CSV import.
public actor TelematicsImportStore {
    private let fileURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(directory: URL? = nil) {
        let dir: URL
        if let directory {
            dir = directory
        } else {
            let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            dir = support.appendingPathComponent("RouteFinder/telematics", isDirectory: true)
        }
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        fileURL = dir.appendingPathComponent("last-import.json")
        encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
    }

    public func load() -> TelematicsImportBatch? {
        guard FileManager.default.fileExists(atPath: fileURL.path),
              let data = try? Data(contentsOf: fileURL),
              let batch = try? decoder.decode(TelematicsImportBatch.self, from: data) else {
            return nil
        }
        return batch
    }

    public func save(_ batch: TelematicsImportBatch) throws {
        let data = try encoder.encode(batch)
        try data.write(to: fileURL, options: .atomic)
    }

    public func clear() {
        try? FileManager.default.removeItem(at: fileURL)
    }
}
