import Contracts
import CoreLocation
import Foundation

/// Decodes Google-encoded polylines used by Valhalla (polyline6) and OSRM (polyline5).
public enum EncodedPolylineDecoder {
    /// Decodes an encoded polyline string into coordinates.
    ///
    /// - Parameters:
    ///   - encoded: The encoded polyline string.
    ///   - precision: Coordinate precision factor exponent (5 → 1e-5°, 6 → 1e-6°).
    /// - Returns: Decoded coordinates, or an empty array when `encoded` is empty.
    public static func decode(_ encoded: String, precision: Int) -> [Coordinate] {
        guard !encoded.isEmpty else { return [] }

        let factor = pow(10.0, Double(precision))
        var coordinates: [Coordinate] = []
        coordinates.reserveCapacity(max(encoded.count / 4, 4))
        var index = encoded.startIndex
        var latitude: Int32 = 0
        var longitude: Int32 = 0

        while index < encoded.endIndex {
            guard let latDelta = decodeComponent(from: encoded, index: &index) else { break }
            latitude &+= latDelta

            guard let lonDelta = decodeComponent(from: encoded, index: &index) else { break }
            longitude &+= lonDelta

            coordinates.append(Coordinate(
                latitude: Double(latitude) / factor,
                longitude: Double(longitude) / factor
            ))
        }

        return coordinates
    }

    /// Decodes an encoded polyline into Core Location map coordinates.
    public static func decodeToMapCoordinates(
        _ encoded: String,
        precision: Int
    ) -> [CLLocationCoordinate2D] {
        decode(encoded, precision: precision).map {
            CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude)
        }
    }

    /// Decodes using a precision factor (e.g. `1e5` for polyline5, `1e6` for polyline6).
    public static func decodeToMapCoordinates(
        _ encoded: String,
        precision factor: Double
    ) -> [CLLocationCoordinate2D] {
        decodeToMapCoordinates(encoded, precision: precisionExponent(for: factor))
    }

    private static func precisionExponent(for factor: Double) -> Int {
        switch factor {
        case 100_000, 1e5:
            return 5
        case 1_000_000, 1e6:
            return 6
        default:
            return Int(round(log10(factor)))
        }
    }

    private static func decodeComponent(from encoded: String, index: inout String.Index) -> Int32? {
        var result: Int32 = 0
        var shift: Int32 = 0
        var byte: Int32 = 0

        repeat {
            guard index < encoded.endIndex else { return nil }
            let character = encoded[index]
            index = encoded.index(after: index)

            guard let ascii = character.asciiValue else { return nil }
            byte = Int32(ascii) - 63
            result |= (byte & 0x1F) << shift
            shift += 5
        } while byte >= 0x20

        let delta = (result & 1) != 0 ? ~(result >> 1) : (result >> 1)
        return delta
    }
}
