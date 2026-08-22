import Contracts
import Foundation

enum CoordinateParsing {
    /// Parses a `lat,lon` pair from CLI text.
    static func parseLatLon(_ text: String) throws -> RoutingCoordinate {
        let parts = text.split(separator: ",", omittingEmptySubsequences: false)
        guard parts.count == 2 else {
            throw ParseError.invalidCoordinate(text)
        }

        let latitudeText = parts[0].trimmingCharacters(in: .whitespaces)
        let longitudeText = parts[1].trimmingCharacters(in: .whitespaces)

        guard let latitude = Double(latitudeText),
              let longitude = Double(longitudeText),
              (-90...90).contains(latitude),
              (-180...180).contains(longitude) else {
            throw ParseError.invalidCoordinate(text)
        }

        return RoutingCoordinate(latitude: latitude, longitude: longitude)
    }

    enum ParseError: Error, LocalizedError {
        case invalidCoordinate(String)

        var errorDescription: String? {
            switch self {
            case .invalidCoordinate(let value):
                return "Invalid coordinate “\(value)”. Expected lat,lon (e.g. 52.63,-1.13)."
            }
        }
    }
}
