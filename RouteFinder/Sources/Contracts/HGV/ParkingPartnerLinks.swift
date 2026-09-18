import Foundation

/// Builds HTTPS deep links to parking partner sites (redirect only — no booking commerce).
public enum ParkingPartnerLinks: Sendable {
    /// TRAVIS truck parking map / search with optional focus coordinate.
    ///
    /// Opens the public TRAVIS web experience. Booking and fees are between the driver
    /// and the parking operator — RouteFinder does not process payments.
    public static func travisURL(
        latitude: Double,
        longitude: Double,
        label: String? = nil
    ) -> URL {
        var components = URLComponents(string: "https://www.yourtravis.com/map")!
        var items: [URLQueryItem] = [
            URLQueryItem(name: "lat", value: String(format: "%.5f", latitude)),
            URLQueryItem(name: "lng", value: String(format: "%.5f", longitude)),
        ]
        if let label {
            let trimmed = label.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                items.append(URLQueryItem(name: "q", value: trimmed))
            }
        }
        components.queryItems = items
        return components.url!
    }

    /// SNAP UK truck parking locator with search focus.
    public static func snapURL(
        latitude: Double,
        longitude: Double,
        label: String? = nil
    ) -> URL {
        var components = URLComponents(string: "https://www.snapacc.com/find-parking")!
        var items: [URLQueryItem] = [
            URLQueryItem(name: "lat", value: String(format: "%.5f", latitude)),
            URLQueryItem(name: "lon", value: String(format: "%.5f", longitude)),
        ]
        if let label {
            let trimmed = label.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                items.append(URLQueryItem(name: "search", value: trimmed))
            }
        }
        components.queryItems = items
        return components.url!
    }

    /// Convenience from a ``Coordinate``.
    public static func travisURL(coordinate: Coordinate, label: String? = nil) -> URL {
        travisURL(latitude: coordinate.latitude, longitude: coordinate.longitude, label: label)
    }

    /// Convenience from a ``Coordinate``.
    public static func snapURL(coordinate: Coordinate, label: String? = nil) -> URL {
        snapURL(latitude: coordinate.latitude, longitude: coordinate.longitude, label: label)
    }
}
