import Contracts
import Testing

struct LaybyAlertFormatterTests {
    @Test func shouldAnnounceInsideThresholdOnce() {
        let stop = LaybyStop(id: "layby-1", coordinate: Coordinate(latitude: 52, longitude: -1), label: "M1 J15")
        let advisory = LaybyAdvisory(
            stop: stop,
            distanceRemainingMeters: 4000,
            estimatedArrivalSeconds: 180
        )
        #expect(
            LaybyAlertFormatter.shouldAnnounce(
                advisory: advisory,
                lastAnnouncedLaybyId: nil,
                alertDistanceMeters: 5000
            )
        )
        #expect(
            !LaybyAlertFormatter.shouldAnnounce(
                advisory: advisory,
                lastAnnouncedLaybyId: "layby-1",
                alertDistanceMeters: 5000
            )
        )
    }

    @Test func shouldNotAnnounceOutsideThreshold() {
        let stop = LaybyStop(id: "layby-2", coordinate: Coordinate(latitude: 52, longitude: -1), label: "A1")
        let advisory = LaybyAdvisory(
            stop: stop,
            distanceRemainingMeters: 8000,
            estimatedArrivalSeconds: 600
        )
        #expect(
            !LaybyAlertFormatter.shouldAnnounce(
                advisory: advisory,
                lastAnnouncedLaybyId: nil,
                alertDistanceMeters: 5000
            )
        )
    }

    @Test func spokenPromptIncludesLabelAndETA() {
        let stop = LaybyStop(id: "layby-3", coordinate: Coordinate(latitude: 52, longitude: -1), label: "Northbound layby")
        let advisory = LaybyAdvisory(
            stop: stop,
            distanceRemainingMeters: 2000,
            estimatedArrivalSeconds: 120
        )
        let prompt = LaybyAlertFormatter.spokenPrompt(for: advisory)
        #expect(prompt.contains("Northbound layby"))
        #expect(prompt.contains("Layby ahead"))
    }

    @Test func nextLaybyToastWhenNoneRemaining() {
        #expect(LaybyAlertFormatter.nextLaybyToast(next: nil) == "No further laybys on this route")
    }

    @Test func nextLaybyToastIncludesReplacement() {
        let stop = LaybyStop(id: "layby-4", coordinate: Coordinate(latitude: 52, longitude: -1), label: "Services")
        let next = LaybyAdvisory(
            stop: stop,
            distanceRemainingMeters: 12000,
            estimatedArrivalSeconds: 480
        )
        let toast = LaybyAlertFormatter.nextLaybyToast(next: next)
        #expect(toast.contains("Next layby"))
        #expect(toast.contains("Services"))
    }
}
