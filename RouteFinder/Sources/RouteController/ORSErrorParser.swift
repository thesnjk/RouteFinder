import Foundation

/// Parses OpenRouteService error JSON into user-facing messages.
enum ORSErrorParser {
    /// Returns a short user-facing message when the body is a known ORS error envelope.
    static func userFacingMessage(status: Int, body: String) -> String? {
        guard let parsed = parse(body: body) else { return nil }
        return userFacingMessage(code: parsed.code, message: parsed.message, status: status)
    }

    /// Returns true when the body indicates an unsupported `extra_info` parameter.
    static func isUnsupportedExtraInfoError(body: String) -> Bool {
        guard let parsed = parse(body: body) else {
            return body.contains("Unknown parameter 'extra_info'")
        }
        if parsed.code == 2012 { return true }
        return parsed.message?.contains("extra_info") == true
    }

    private static func parse(body: String) -> ParsedORSError? {
        let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let data = trimmed.data(using: .utf8) else { return nil }
        guard let envelope = try? JSONDecoder().decode(ORSErrorEnvelope.self, from: data),
              let error = envelope.error else {
            return nil
        }
        return ParsedORSError(code: error.code, message: error.message)
    }

    private static func userFacingMessage(code: Int?, message: String?, status: Int) -> String {
        if code == 2012 {
            return "Routing service does not support this request option. Try again or check for an app update."
        }
        if code == 2003 {
            return "Routing failed: an avoid zone is too large for the routing service. Turn off LEZ avoid or set a compliant emission class, then try again."
        }
        if code == 2004, let message, message.localizedCaseInsensitiveContains("avoid") {
            return "Routing failed: this trip is too long for LEZ avoid areas on the current OpenRouteService plan (max ~150 km with avoids). Turn off LEZ avoid or set a compliant emission class, then try again."
        }
        if let message, !message.isEmpty {
            return "Routing failed: \(message)"
        }
        return "Routing server error (HTTP \(status))."
    }
}

private struct ParsedORSError {
    let code: Int?
    let message: String?
}

private struct ORSErrorEnvelope: Decodable {
    let error: ORSErrorBody?
}

private struct ORSErrorBody: Decodable {
    let code: Int?
    let message: String?
}
