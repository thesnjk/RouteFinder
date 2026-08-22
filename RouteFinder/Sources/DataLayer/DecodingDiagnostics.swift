import Foundation

/// Shared diagnostics for JSON decoding failures across data-layer clients.
public enum DecodingDiagnostics {
    /// Logs a decoding error with context and optional response preview to the console.
    public static func logDecodingError(
        _ error: Error,
        context: String,
        responsePreview: String? = nil
    ) {
        var lines = ["[DecodingDiagnostics] \(context)"]
        if let preview = responsePreview {
            lines.append("Response preview: \(preview)")
        }
        if let decoding = error as? DecodingError {
            lines.append(describe(decoding))
        } else {
            lines.append(error.localizedDescription)
        }
        print(lines.joined(separator: "\n"))
    }

    /// Returns a user-facing error message for display in the UI.
    public static func userMessage(for error: Error) -> String {
        if let decoding = error as? DecodingError {
            return userMessage(for: decoding)
        }
        return error.localizedDescription
    }

    /// Truncates raw response data for console logging.
    public static func preview(of data: Data, maxLength: Int = 512) -> String {
        guard let text = String(data: data, encoding: .utf8) else {
            return "<\(data.count) bytes, non-UTF8>"
        }
        if text.count <= maxLength { return text }
        let end = text.index(text.startIndex, offsetBy: maxLength)
        return String(text[..<end]) + "…"
    }

    private static func userMessage(for error: DecodingError) -> String {
        switch error {
        case .keyNotFound(let key, let context):
            let path = codingPathString(context.codingPath)
            return "Data format error: missing field “\(key.stringValue)”\(path.isEmpty ? "" : " at \(path)"). Try clearing the cache in Settings."
        case .valueNotFound(_, let context):
            let path = codingPathString(context.codingPath)
            return "Data format error: missing value\(path.isEmpty ? "" : " at \(path)"). Try clearing the cache in Settings."
        case .typeMismatch(_, let context):
            let path = codingPathString(context.codingPath)
            return "Data format error: unexpected type\(path.isEmpty ? "" : " at \(path)"). Try clearing the cache in Settings."
        case .dataCorrupted(let context):
            let path = codingPathString(context.codingPath)
            return "Data format error: corrupted data\(path.isEmpty ? "" : " at \(path)"). Try clearing the cache in Settings."
        @unknown default:
            return "Data could not be read. Try clearing the cache in Settings."
        }
    }

    private static func describe(_ error: DecodingError) -> String {
        switch error {
        case .keyNotFound(let key, let context):
            return "keyNotFound: \(key.stringValue) at \(codingPathString(context.codingPath))"
        case .valueNotFound(let type, let context):
            return "valueNotFound: \(type) at \(codingPathString(context.codingPath))"
        case .typeMismatch(let type, let context):
            return "typeMismatch: \(type) at \(codingPathString(context.codingPath))"
        case .dataCorrupted(let context):
            return "dataCorrupted at \(codingPathString(context.codingPath)): \(context.debugDescription)"
        @unknown default:
            return "unknown DecodingError"
        }
    }

    private static func codingPathString(_ path: [CodingKey]) -> String {
        path.map(\.stringValue).joined(separator: ".")
    }
}
