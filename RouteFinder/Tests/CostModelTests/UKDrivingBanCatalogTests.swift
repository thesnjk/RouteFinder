import Contracts
import Foundation
import Testing

@Test func ukDrivingBanCatalogDetectsLondonCorridorAtNight() {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Europe/London")!

    // Wednesday 23:00 local — LCS overnight window.
    var components = DateComponents()
    components.year = 2026
    components.month = 3
    components.day = 11 // Wednesday
    components.hour = 23
    components.minute = 0
    let night = calendar.date(from: components)!

    let route = [
        Coordinate(latitude: 51.45, longitude: -0.20),
        Coordinate(latitude: 51.50, longitude: -0.13),
        Coordinate(latitude: 51.55, longitude: -0.05),
    ]
    let announcements = UKDrivingBanCatalog.announcements(
        along: route,
        at: night,
        calendar: calendar
    )
    #expect(announcements.contains { $0.zoneId == "london-lcs" })
    #expect(announcements.contains { $0.kind == .noDrive })
}

@Test func ukDrivingBanCatalogQuietDuringWeekdayDaytime() {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Europe/London")!

    var components = DateComponents()
    components.year = 2026
    components.month = 3
    components.day = 11 // Wednesday
    components.hour = 14
    components.minute = 0
    let afternoon = calendar.date(from: components)!

    let route = [
        Coordinate(latitude: 51.45, longitude: -0.20),
        Coordinate(latitude: 51.50, longitude: -0.13),
        Coordinate(latitude: 51.55, longitude: -0.05),
    ]
    let announcements = UKDrivingBanCatalog.announcements(
        along: route,
        at: afternoon,
        calendar: calendar
    )
    #expect(!announcements.contains { $0.zoneId == "london-lcs" })
}
