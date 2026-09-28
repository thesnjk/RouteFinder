import Contracts
import CoreLocation
import MapLibreUI
import SwiftUI

/// Lightweight map showing dispatched stop pins, yard GPS pins, and route preview polyline.
struct DispatchMapDetailView: View {
    let trip: FleetTrip?
    let draft: DispatchTripDraft
    let previewCoordinates: [CLLocationCoordinate2D]
    let isPreviewLoading: Bool
    var fleetPins: [DispatchRosterPin] = []
    var selectedVehicleId: UUID?

    @StateObject private var mapBridge = MapViewControllerBridge()

    var body: some View {
        ZStack(alignment: .topTrailing) {
            MapRouteView(
                coordinates: previewCoordinates.isEmpty ? polylineCoordinates : previewCoordinates,
                pins: mapPins,
                simulatedVehicle: driverVehicleState,
                initialRegion: mapRegion,
                mapBridge: mapBridge,
                onMapClick: { _ in },
                onContextAction: { _, _ in },
                onRegionChange: { _ in }
            )
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            if isPreviewLoading {
                ProgressView()
                    .controlSize(.small)
                    .padding(RFSpacing.sm)
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding(RFSpacing.md)
            }

            if showsEmptyCaption {
                Text("No trip preview — set stops or wait for cab GPS")
                    .font(RFFont.caption.weight(.semibold))
                    .padding(.horizontal, RFSpacing.md)
                    .padding(.vertical, RFSpacing.sm)
                    .background(.ultraThinMaterial, in: Capsule())
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                    .padding(RFSpacing.md)
            }
        }
        .padding(RFSpacing.md)
    }

    private var showsEmptyCaption: Bool {
        displayStops.isEmpty && fleetPins.isEmpty && previewCoordinates.isEmpty
    }

    private var displayStops: [(label: String, lat: Double, lon: Double, role: FleetTripStop.Role)] {
        if let trip, !trip.stops.isEmpty {
            return trip.stops.sorted { $0.sequence < $1.sequence }.map {
                ($0.label, $0.latitude, $0.longitude, $0.role)
            }
        }
        return draft.stops.compactMap { stop in
            guard let lat = Double(stop.latitude), let lon = Double(stop.longitude) else { return nil }
            let role: FleetTripStop.Role = switch stop.id {
            case draft.stops.first?.id: .origin
            case draft.stops.last?.id: .destination
            default: .via
            }
            return (stop.label.isEmpty ? "Stop" : stop.label, lat, lon, role)
        }
    }

    private var polylineCoordinates: [CLLocationCoordinate2D] {
        displayStops.map { CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lon) }
    }

    private var mapPins: [RoutePin] {
        var pins = displayStops.enumerated().map { index, stop in
            let kind: RoutePin.PinKind = switch stop.role {
            case .origin: .start
            case .destination: .end
            case .via: .waypoint
            }
            return RoutePin(
                id: "stop-\(index)",
                coordinate: CLLocationCoordinate2D(latitude: stop.lat, longitude: stop.lon),
                kind: kind,
                title: stop.label
            )
        }
        for pin in fleetPins where pin.vehicleId != selectedVehicleId {
            pins.append(
                RoutePin(
                    id: "fleet-\(pin.vehicleId.uuidString)",
                    coordinate: CLLocationCoordinate2D(latitude: pin.latitude, longitude: pin.longitude),
                    kind: .waypoint,
                    title: pin.label
                )
            )
        }
        return pins
    }

    private var driverVehicleState: SimulatedVehicleState? {
        guard let trip,
              let latitude = trip.driverLatitude,
              let longitude = trip.driverLongitude else {
            return nil
        }
        return SimulatedVehicleState(
            latitude: latitude,
            longitude: longitude,
            bearing: 0,
            visible: true
        )
    }

    private var mapRegion: MapRegion {
        var coords = previewCoordinates.isEmpty ? polylineCoordinates : previewCoordinates
        if let trip,
           let latitude = trip.driverLatitude,
           let longitude = trip.driverLongitude {
            coords.append(CLLocationCoordinate2D(latitude: latitude, longitude: longitude))
        }
        for pin in fleetPins {
            coords.append(CLLocationCoordinate2D(latitude: pin.latitude, longitude: pin.longitude))
        }
        guard coords.first != nil else {
            // Norfolk depot (demo corridor) — regional UK zoom, not empty Europe.
            return MapRegion(
                center: CLLocationCoordinate2D(latitude: 52.6309, longitude: 1.2974),
                latitudeDelta: 1.8,
                longitudeDelta: 1.8
            )
        }
        let lats = coords.map(\.latitude)
        let lons = coords.map(\.longitude)
        let center = CLLocationCoordinate2D(
            latitude: (lats.min()! + lats.max()!) / 2,
            longitude: (lons.min()! + lons.max()!) / 2
        )
        let spanLat = max(0.5, (lats.max()! - lats.min()!) * 1.4)
        let spanLon = max(0.5, (lons.max()! - lons.min()!) * 1.4)
        return MapRegion(center: center, latitudeDelta: spanLat, longitudeDelta: spanLon)
    }
}
