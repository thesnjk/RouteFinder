import Contracts
import Foundation
import MapKit

/// Apple MapKit local search fallback when HeiGIT Pelias is unavailable or returns no results.
public actor AppleGeocodeSearch {
    public init() {}

    /// Searches for places near the given coordinate using MapKit.
    public func search(query: String, near: Coordinate, limit: Int = 8) async -> [GeocodeSuggestion] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard trimmed.count >= 2 else { return [] }

        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = trimmed
        request.resultTypes = [.address, .pointOfInterest]
        request.region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: near.latitude, longitude: near.longitude),
            latitudinalMeters: 500_000,
            longitudinalMeters: 500_000
        )

        let search = MKLocalSearch(request: request)
        do {
            let response = try await search.start()
            return response.mapItems.prefix(limit).compactMap { item in
                suggestion(from: item, fallbackTitle: trimmed)
            }
        } catch {
            return []
        }
    }

    private func suggestion(from item: MKMapItem, fallbackTitle: String) -> GeocodeSuggestion? {
        let placemark = item.placemark
        let coordinate: Coordinate
        if let location = placemark.location {
            coordinate = Coordinate(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)
        } else {
            coordinate = Coordinate(latitude: placemark.coordinate.latitude, longitude: placemark.coordinate.longitude)
        }
        let title = item.name ?? fallbackTitle
        let subtitle = formatPlacemark(item.placemark) ?? title
        let stableID = String(format: "%.5f,%.5f", coordinate.latitude, coordinate.longitude)

        return GeocodeSuggestion(
            id: "apple:\(stableID)",
            title: title,
            subtitle: subtitle,
            coordinate: coordinate,
            isLocal: false
        )
    }

    private func formatPlacemark(_ placemark: MKPlacemark) -> String? {
        let parts = [
            placemark.name,
            placemark.locality,
            placemark.administrativeArea,
            placemark.country,
        ]
        .compactMap { $0 }
        .filter { !$0.isEmpty }

        guard !parts.isEmpty else { return nil }
        return parts.joined(separator: ", ")
    }
}
