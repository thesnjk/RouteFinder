import Contracts
import CoreLocation
import MapKit

#if canImport(UIKit)
import UIKit
private typealias PlatformColor = UIColor
#elseif canImport(AppKit)
import AppKit
private typealias PlatformColor = NSColor
#endif

/// Renders a static MapKit route overview for PDF trip brief export.
public enum RouteMapSnapshotRenderer {
    /// Default snapshot size for letter-width PDF embedding.
    public static let defaultSize = CGSize(width: 536, height: 280)

    /// Captures a map snapshot with route polyline and stop pin overlays.
    public static func snapshot(
        routeCoordinates: [Coordinate],
        stopCoordinates: [Coordinate] = [],
        size: CGSize = defaultSize
    ) async -> Data? {
        guard routeCoordinates.count >= 2 else { return nil }

        let routeCLCoordinates = routeCoordinates.map {
            CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude)
        }
        guard let region = RoutePolyline.mapRegion(for: routeCLCoordinates) else { return nil }

        let options = MKMapSnapshotter.Options()
        options.region = MKCoordinateRegion(
            center: region.center,
            span: MKCoordinateSpan(
                latitudeDelta: region.latitudeDelta,
                longitudeDelta: region.longitudeDelta
            )
        )
        options.size = size

        let snapshotter = MKMapSnapshotter(options: options)
        let snapshot: MKMapSnapshotter.Snapshot
        do {
            snapshot = try await snapshotter.start()
        } catch {
            return nil
        }

        let stopCLCoordinates = stopCoordinates.map {
            CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude)
        }

        #if canImport(UIKit)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            snapshot.image.draw(at: .zero)
            drawOverlays(
                on: context.cgContext,
                snapshot: snapshot,
                routeCoordinates: routeCLCoordinates,
                stopCoordinates: stopCLCoordinates
            )
        }
        return image.pngData()
        #elseif canImport(AppKit)
        let image = NSImage(size: size)
        image.lockFocus()
        snapshot.image.draw(
            in: NSRect(origin: .zero, size: size),
            from: NSRect(origin: .zero, size: snapshot.image.size),
            operation: .copy,
            fraction: 1
        )
        if let context = NSGraphicsContext.current?.cgContext {
            drawOverlays(
                on: context,
                snapshot: snapshot,
                routeCoordinates: routeCLCoordinates,
                stopCoordinates: stopCLCoordinates
            )
        }
        image.unlockFocus()
        guard let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff) else {
            return nil
        }
        return bitmap.representation(using: .png, properties: [:])
        #else
        return nil
        #endif
    }

    private static func drawOverlays(
        on context: CGContext,
        snapshot: MKMapSnapshotter.Snapshot,
        routeCoordinates: [CLLocationCoordinate2D],
        stopCoordinates: [CLLocationCoordinate2D]
    ) {
        context.saveGState()
        context.setLineWidth(3)
        context.setLineJoin(.round)
        context.setLineCap(.round)
        context.setStrokeColor(routeStrokeColor().cgColor)

        let routePoints = routeCoordinates.map { snapshot.point(for: $0) }
        if let first = routePoints.first {
            context.beginPath()
            context.move(to: first)
            for point in routePoints.dropFirst() {
                context.addLine(to: point)
            }
            context.strokePath()
        }

        if let origin = routeCoordinates.first {
            drawPin(at: snapshot.point(for: origin), color: originPinColor(), in: context)
        }
        if routeCoordinates.count > 1, let destination = routeCoordinates.last {
            drawPin(at: snapshot.point(for: destination), color: destinationPinColor(), in: context)
        }

        for stop in stopCoordinates where !routeCoordinates.contains(where: { $0.isNear(stop) }) {
            drawPin(at: snapshot.point(for: stop), color: viaPinColor(), radius: 5, in: context)
        }

        context.restoreGState()
    }

    private static func drawPin(
        at point: CGPoint,
        color: PlatformColor,
        radius: CGFloat = 6,
        in context: CGContext
    ) {
        let rect = CGRect(
            x: point.x - radius,
            y: point.y - radius,
            width: radius * 2,
            height: radius * 2
        )
        context.setFillColor(color.cgColor)
        context.fillEllipse(in: rect)
        context.setStrokeColor(PlatformColor.white.cgColor)
        context.setLineWidth(1.5)
        context.strokeEllipse(in: rect)
    }

    private static func routeStrokeColor() -> PlatformColor {
        #if canImport(UIKit)
        return UIColor.systemBlue
        #else
        return NSColor.systemBlue
        #endif
    }

    private static func originPinColor() -> PlatformColor {
        #if canImport(UIKit)
        return UIColor.systemGreen
        #else
        return NSColor.systemGreen
        #endif
    }

    private static func destinationPinColor() -> PlatformColor {
        #if canImport(UIKit)
        return UIColor.systemRed
        #else
        return NSColor.systemRed
        #endif
    }

    private static func viaPinColor() -> PlatformColor {
        #if canImport(UIKit)
        return UIColor.systemOrange
        #else
        return NSColor.systemOrange
        #endif
    }
}

private extension CLLocationCoordinate2D {
    func isNear(_ other: CLLocationCoordinate2D, tolerance: Double = 0.0001) -> Bool {
        abs(latitude - other.latitude) < tolerance && abs(longitude - other.longitude) < tolerance
    }
}
