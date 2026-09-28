import DataLayer
import Foundation
import Testing

@Suite("FleetProxyDeskStatus")
struct FleetProxyDeskStatusTests {
    @Test func decodesFullFixtureJSON() throws {
        let json = """
        {
          "orsConfigured": true,
          "routesToday": 12,
          "routeDailyCap": 2000,
          "geocodeToday": 40,
          "geocodeDailyCap": 500,
          "tomTomConfigured": true,
          "openWeatherConfigured": false,
          "overpassConfigured": true,
          "tomTomToday": 3,
          "tomTomDailyCap": 500,
          "openWeatherToday": 0,
          "openWeatherDailyCap": 200,
          "overpassToday": 1,
          "overpassDailyCap": 100
        }
        """.data(using: .utf8)!
        let status = try JSONDecoder().decode(FleetProxyDeskStatus.self, from: json)
        #expect(status.orsConfigured)
        #expect(status.routesToday == 12)
        #expect(status.routeDailyCap == 2000)
        #expect(status.routesRemaining == 1988)
        #expect(status.geocodesRemaining == 460)
        #expect(status.tomTomConfigured)
        #expect(!status.openWeatherConfigured)
        #expect(status.tomTomToday == 3)
        #expect(!status.isNearAnyORSCap)
    }

    @Test func tolerantDecodeOlderMinimalJSON() throws {
        let json = """
        {"orsConfigured":false,"routesToday":0,"routeDailyCap":100,"geocodeToday":0,"geocodeDailyCap":50}
        """.data(using: .utf8)!
        let status = try JSONDecoder().decode(FleetProxyDeskStatus.self, from: json)
        #expect(!status.orsConfigured)
        #expect(!status.tomTomConfigured)
        #expect(status.orsSummaryLine.contains("off"))
        #expect(status.nearCapWarning == nil)
    }

    @Test func remainingNeverNegative() {
        let status = FleetProxyDeskStatus(
            orsConfigured: true,
            routesToday: 2100,
            routeDailyCap: 2000,
            geocodeToday: 600,
            geocodeDailyCap: 500
        )
        #expect(status.routesRemaining == 0)
        #expect(status.geocodesRemaining == 0)
    }

    @Test func nearCapAtNinetyPercent() {
        let near = FleetProxyDeskStatus(
            orsConfigured: true,
            routesToday: 900,
            routeDailyCap: 1000,
            geocodeToday: 10,
            geocodeDailyCap: 500
        )
        #expect(near.isNearRouteCap)
        #expect(!near.isNearGeocodeCap)
        #expect(near.isNearAnyORSCap)
        #expect(near.nearCapWarning != nil)

        let ok = FleetProxyDeskStatus(
            orsConfigured: true,
            routesToday: 899,
            routeDailyCap: 1000,
            geocodeToday: 10,
            geocodeDailyCap: 500
        )
        #expect(!ok.isNearRouteCap)
        #expect(ok.nearCapWarning == nil)
    }

    @Test func summaryLinesMatchWebStyle() {
        let status = FleetProxyDeskStatus(
            orsConfigured: true,
            routesToday: 12,
            routeDailyCap: 2000,
            geocodeToday: 40,
            geocodeDailyCap: 500,
            tomTomConfigured: true,
            openWeatherConfigured: true,
            tomTomToday: 1,
            tomTomDailyCap: 500,
            openWeatherToday: 2,
            openWeatherDailyCap: 200
        )
        let lines = status.summaryLines
        #expect(lines.count == 2)
        #expect(lines[0].contains("12/2000 routes"))
        #expect(lines[0].contains("1988 left"))
        #expect(lines[1].contains("TomTom: on"))
        #expect(lines[1].contains("OpenWeather: on"))
    }
}
