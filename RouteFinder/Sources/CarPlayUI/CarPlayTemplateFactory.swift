#if os(iOS)
import CarPlay
import Contracts
import CoreLocation
import Foundation
import MapKit

/// Factory helpers for CarPlay trip and route choice construction.
public enum CarPlayTemplateFactory {
    /// Builds a CarPlay trip from route endpoints and route choices.
    public static func makeTrip(
        origin: CLLocationCoordinate2D,
        destination: CLLocationCoordinate2D,
        routeChoices: [CPRouteChoice],
        routeName: String = "RouteFinder Route"
    ) -> CPTrip {
        let originItem = mapItem(at: origin, name: "Origin")
        let destinationItem = mapItem(at: destination, name: "Destination")
        return CPTrip(origin: originItem, destination: destinationItem, routeChoices: routeChoices)
    }

    /// Builds a route choice summary for CarPlay navigation.
    public static func makeRouteChoice(
        name: String,
        distanceMeters: Double,
        timeSeconds: TimeInterval
    ) -> CPRouteChoice {
        let summary = String(format: "%.1f km • %@", distanceMeters / 1000, formatDuration(timeSeconds))
        return CPRouteChoice(
            summaryVariants: [summary],
            additionalInformationVariants: [name],
            selectionSummaryVariants: [summary]
        )
    }

    /// Maps a turn instruction to a CarPlay maneuver template.
    public static func makeManeuver(from instruction: TurnInstruction) -> CPManeuver {
        let maneuver = CPManeuver()
        maneuver.initialTravelEstimates = CPTravelEstimates(
            distanceRemaining: Measurement(value: instruction.distance, unit: .meters),
            timeRemaining: 0
        )
        let road = instruction.roadName ?? "Road"
        maneuver.instructionVariants = [
            ManeuverSpeechFormatter.displayDescription(for: instruction.maneuver, roadName: road)
        ]
        return maneuver
    }

    private static func mapItem(at coordinate: CLLocationCoordinate2D, name: String) -> MKMapItem {
        if #available(iOS 26.0, *) {
            let item = MKMapItem(
                location: CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude),
                address: MKAddress(fullAddress: name, shortAddress: name)
            )
            item.name = name
            return item
        }

        let placemark = MKPlacemark(coordinate: coordinate)
        let item = MKMapItem(placemark: placemark)
        item.name = name
        return item
    }

    private static func formatDuration(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds) / 60
        if minutes < 60 { return "\(minutes) min" }
        return "\(minutes / 60)h \(minutes % 60)m"
    }
}
#endif
