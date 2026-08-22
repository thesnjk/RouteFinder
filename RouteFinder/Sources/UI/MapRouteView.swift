import CoreLocation
import MapLibreUI
import SwiftUI

#if os(macOS)
import AppKit
import ObjectiveC
#endif

/// MapLibre map view displaying route polyline, pins, and interaction callbacks.
public struct MapRouteView: View {
    let coordinates: [CLLocationCoordinate2D]
    let encodedPolyline: String?
    let encodedPolylinePrecision: Int
    let routeCumulativeLengths: [Double]
    let pins: [RoutePin]
    let hazardsGeoJSON: String
    let simulatedVehicle: SimulatedVehicleState?
    let interactionMode: MapInteractionMode
    let initialRegion: MapRegion
    let mapBridge: MapViewControllerBridge?
    let onMapClick: (CLLocationCoordinate2D) -> Void
    let onContextAction: (MapContextAction, CLLocationCoordinate2D) -> Void
    let onRegionChange: (CLLocationCoordinate2D) -> Void

    public init(
        coordinates: [CLLocationCoordinate2D],
        encodedPolyline: String? = nil,
        encodedPolylinePrecision: Int = 6,
        routeCumulativeLengths: [Double] = [],
        pins: [RoutePin] = [],
        hazardsGeoJSON: String = "{\"type\":\"FeatureCollection\",\"features\":[]}",
        simulatedVehicle: SimulatedVehicleState? = nil,
        interactionMode: MapInteractionMode = .navigate,
        initialRegion: MapRegion,
        mapBridge: MapViewControllerBridge? = nil,
        onMapClick: @escaping (CLLocationCoordinate2D) -> Void = { _ in },
        onContextAction: @escaping (MapContextAction, CLLocationCoordinate2D) -> Void = { _, _ in },
        onRegionChange: @escaping (CLLocationCoordinate2D) -> Void = { _ in }
    ) {
        self.coordinates = coordinates
        self.encodedPolyline = encodedPolyline
        self.encodedPolylinePrecision = encodedPolylinePrecision
        self.routeCumulativeLengths = routeCumulativeLengths
        self.pins = pins
        self.hazardsGeoJSON = hazardsGeoJSON
        self.simulatedVehicle = simulatedVehicle
        self.interactionMode = interactionMode
        self.initialRegion = initialRegion
        self.mapBridge = mapBridge
        self.onMapClick = onMapClick
        self.onContextAction = onContextAction
        self.onRegionChange = onRegionChange
    }

    public var body: some View {
        ZStack(alignment: .bottomLeading) {
            MapLibreWebMapView(
                coordinates: coordinates,
                encodedPolyline: encodedPolyline,
                encodedPolylinePrecision: encodedPolylinePrecision,
                routeCumulativeLengths: routeCumulativeLengths,
                pins: mapLibrePins,
                hazardsGeoJSON: hazardsGeoJSON,
                simulatedVehicle: simulatedVehicle,
                interactionMode: libreInteractionMode,
                region: initialRegion,
                mapBridge: mapBridge,
                onMapClick: onMapClick,
                onContextMenu: { coordinate in
                    #if os(macOS)
                    showContextMenu(at: coordinate)
                    #else
                    onContextAction(.setEnd, coordinate)
                    #endif
                },
                onRegionChange: onRegionChange
            )

            MapAttributionOverlay()
                .padding(RFSpacing.sm)
        }
    }

    private var libreInteractionMode: MapLibreInteractionMode {
        if case .setPin = interactionMode { return .pin }
        return .navigate
    }

    private var mapLibrePins: [MapLibrePin] {
        pins.map { pin in
            MapLibrePin(
                id: pin.id,
                coordinate: pin.coordinate,
                colorHex: pinColorHex(for: pin.kind),
                title: pin.title
            )
        }
    }

    private func pinColorHex(for kind: RoutePin.PinKind) -> String {
        switch kind {
        case .start: return "#22c55e"
        case .end: return "#ef4444"
        case .waypoint: return "#a855f7"
        }
    }

    #if os(macOS)
    private func showContextMenu(at coordinate: CLLocationCoordinate2D) {
        let menu = NSMenu()
        menu.addItem(makeItem("Set as Start", action: .setStart, coordinate: coordinate))
        menu.addItem(makeItem("Set as End", action: .setEnd, coordinate: coordinate))
        menu.addItem(makeItem("Add Stop Here", action: .addStop, coordinate: coordinate))
        menu.popUp(positioning: nil, at: NSEvent.mouseLocation, in: nil)
    }

    private func makeItem(_ title: String, action: MapContextAction, coordinate: CLLocationCoordinate2D) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: #selector(ContextMenuTarget.handleAction(_:)), keyEquivalent: "")
        let target = ContextMenuTarget { onContextAction(action, coordinate) }
        objc_setAssociatedObject(item, &AssociatedKeys.menuTarget, target, .OBJC_ASSOCIATION_RETAIN)
        item.target = target
        return item
    }
    #endif
}

#if os(macOS)
private enum AssociatedKeys {
    nonisolated(unsafe) static var menuTarget: UInt8 = 0
}

private final class ContextMenuTarget: NSObject {
    private let handler: () -> Void

    init(handler: @escaping () -> Void) {
        self.handler = handler
    }

    @objc func handleAction(_ sender: NSMenuItem) {
        handler()
    }
}
#endif
