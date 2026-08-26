import Contracts
import CoreLocation
import MapLibreUI
import SwiftUI

/// Lightweight map showing dispatched stop pins and a straight-line preview.
struct DispatchMapDetailView: View {
    let trip: FleetTrip?
    let draft: DispatchTripDraft

    @StateObject private var mapBridge = MapViewControllerBridge()

    var body: some View {
        MapRouteView(
            coordinates: polylineCoordinates,
            pins: mapPins,
            initialRegion: mapRegion,
            mapBridge: mapBridge,
            onMapClick: { _ in },
            onContextAction: { _, _ in },
            onRegionChange: { _ in }
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .padding(RFSpacing.md)
    }

    private var displayStops: [(label: String, lat: Double, lon: Double, role: FleetTripStop.Role)] {
        if let trip, !trip.stops.isEmpty {
            return trip.stops.sorted { $0.sequence < $1.sequence }.map {
                ($0.label, $0.latitude, $0.longitude, $0.role)
            }
        }
        return draft.stops.compactMap { stop in
            guard let lat = Double(stop.latitude), let lon = Double(stop.longitude) else { return nil }
            return (stop.label.isEmpty ? "Stop" : stop.label, lat, lon, FleetTripStop.Role.via)
        }
    }

    private var polylineCoordinates: [CLLocationCoordinate2D] {
        displayStops.map { CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lon) }
    }

    private var mapPins: [RoutePin] {
        displayStops.enumerated().map { index, stop in
            let kind: RoutePin.PinKind = switch stop.role {
            case .origin: .start
            case .destination: .end
            case .via: .waypoint
            }
            if displayStops.count == draft.stops.count, trip == nil, index == 0 {
                return RoutePin(
                    id: "draft-\(index)",
                    coordinate: CLLocationCoordinate2D(latitude: stop.lat, longitude: stop.lon),
                    kind: .start,
                    title: stop.label
                )
            }
            if displayStops.count == draft.stops.count, trip == nil, index == displayStops.count - 1 {
                return RoutePin(
                    id: "draft-\(index)",
                    coordinate: CLLocationCoordinate2D(latitude: stop.lat, longitude: stop.lon),
                    kind: .end,
                    title: stop.label
                )
            }
            return RoutePin(
                id: "stop-\(index)",
                coordinate: CLLocationCoordinate2D(latitude: stop.lat, longitude: stop.lon),
                kind: kind,
                title: stop.label
            )
        }
    }

    private var mapRegion: MapRegion {
        guard let first = polylineCoordinates.first else {
            return MapRegion(
                center: CLLocationCoordinate2D(latitude: MapDefaults.ukCenter.latitude, longitude: MapDefaults.ukCenter.longitude),
                latitudeDelta: 6,
                longitudeDelta: 6
            )
        }
        let lats = polylineCoordinates.map(\.latitude)
        let lons = polylineCoordinates.map(\.longitude)
        let center = CLLocationCoordinate2D(
            latitude: (lats.min()! + lats.max()!) / 2,
            longitude: (lons.min()! + lons.max()!) / 2
        )
        let spanLat = max(0.5, (lats.max()! - lats.min()!) * 1.4)
        let spanLon = max(0.5, (lons.max()! - lons.min()!) * 1.4)
        return MapRegion(center: center, latitudeDelta: spanLat, longitudeDelta: spanLon)
    }
}
