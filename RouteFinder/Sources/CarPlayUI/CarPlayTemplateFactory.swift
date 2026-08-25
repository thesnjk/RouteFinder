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

    /// Maps a turn instruction to a CarPlay maneuver aligned with phone voice labels.
    public static func makeManeuver(
        from instruction: TurnInstruction,
        remainingETASeconds: TimeInterval? = nil,
        remainingDistanceMeters: Double? = nil
    ) -> CPManeuver {
        let maneuver = CPManeuver()
        let timeRemaining = estimatedTimeRemaining(
            for: instruction,
            remainingETASeconds: remainingETASeconds,
            remainingDistanceMeters: remainingDistanceMeters
        )
        maneuver.initialTravelEstimates = CPTravelEstimates(
            distanceRemaining: Measurement(value: max(0, instruction.distance), unit: .meters),
            timeRemaining: timeRemaining
        )
        let road = instruction.roadName ?? "Road"
        let display = ManeuverSpeechFormatter.displayDescription(for: instruction.maneuver, roadName: road)
        let spoken = ManeuverSpeechFormatter.spokenPrompt(for: instruction, tier: .execute)
        // Prefer voice-aligned wording first so CarPlay TBT matches iPhone announcements.
        maneuver.instructionVariants = Array(Set([spoken, display]))
        return maneuver
    }

    private static func estimatedTimeRemaining(
        for instruction: TurnInstruction,
        remainingETASeconds: TimeInterval?,
        remainingDistanceMeters: Double?
    ) -> TimeInterval {
        if let eta = remainingETASeconds,
           let remaining = remainingDistanceMeters,
           remaining > 1 {
            return max(0, eta * (instruction.distance / remaining))
        }
        // ~48 km/h cruise fallback for pre-trip seeding.
        return max(0, instruction.distance / 13.3)
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
