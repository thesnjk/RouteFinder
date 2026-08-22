import Contracts
import Foundation

/// Errors during CSV parsing.
public enum CSVParseError: Error, Sendable {
    case fileNotFound(String)
    case invalidFormat(line: Int, reason: String)
    case emptyFile
}

/// Streaming CSV line parser optimized for large graph files.
public enum CSVParser {
    /// Reads all lines from a file asynchronously.
    public static func readLines(from path: String) async throws -> [Substring] {
        let url = URL(fileURLWithPath: path)
        guard FileManager.default.fileExists(atPath: path) else {
            throw CSVParseError.fileNotFound(path)
        }

        let data = try Data(contentsOf: url)
        guard !data.isEmpty else {
            throw CSVParseError.emptyFile
        }

        guard let content = String(data: data, encoding: .utf8) else {
            throw CSVParseError.invalidFormat(line: 0, reason: "Unable to decode UTF-8")
        }

        return content.split(whereSeparator: \.isNewline)
    }

    /// Parses a boolean field from CSV ("true", "1", "yes" → true).
    public static func parseBool(_ field: Substring) -> Bool {
        let lower = field.trimmingCharacters(in: .whitespaces).lowercased()
        return lower == "true" || lower == "1" || lower == "yes"
    }

    /// Parses an optional double field; empty string → nil.
    public static func parseOptionalDouble(_ field: Substring) -> Double? {
        let trimmed = field.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }
        return Double(trimmed)
    }

    /// Parses a required double field.
    public static func parseDouble(_ field: Substring) -> Double? {
        Double(field.trimmingCharacters(in: .whitespaces))
    }

    /// Parses a road type from CSV string.
    public static func parseRoadType(_ field: Substring) -> RoadType {
        RoadType(rawValue: String(field.trimmingCharacters(in: .whitespaces).lowercased())) ?? .unknown
    }

    /// Parses a camera type from CSV string.
    public static func parseCameraType(_ field: Substring) -> CameraType? {
        let raw = String(field.trimmingCharacters(in: .whitespaces).lowercased())
        guard !raw.isEmpty else { return nil }
        return CameraType(rawValue: raw)
    }

    /// Splits a CSV line into fields, skipping comment lines.
    public static func splitLine(_ line: Substring) -> [Substring]? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty || trimmed.hasPrefix("#") { return nil }
        if trimmed.lowercased().hasPrefix("id,") || trimmed.lowercased().hasPrefix("from,") { return nil }
        return trimmed.split(separator: ",", omittingEmptySubsequences: false)
    }
}
