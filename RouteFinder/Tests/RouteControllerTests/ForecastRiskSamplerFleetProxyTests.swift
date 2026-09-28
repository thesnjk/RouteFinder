import Foundation
import Testing
@testable import RouteController

@Suite("ForecastRiskSampler fleet proxy")
struct ForecastRiskSamplerFleetProxyTests {
    @Test func prefersFleetWhenConfigured() {
        let base = URL(string: "http://192.168.1.10:8080")!
        #expect(
            ForecastRiskSampler.prefersFleetTomTom(fleetBaseURL: base, tomTomProxyConfigured: true)
        )
        #expect(
            !ForecastRiskSampler.prefersFleetTomTom(fleetBaseURL: base, tomTomProxyConfigured: false)
        )
        #expect(
            !ForecastRiskSampler.prefersFleetTomTom(fleetBaseURL: nil, tomTomProxyConfigured: true)
        )
        #expect(
            ForecastRiskSampler.prefersFleetOpenWeather(
                fleetBaseURL: base,
                openWeatherProxyConfigured: true
            )
        )
        #expect(
            !ForecastRiskSampler.prefersFleetOpenWeather(
                fleetBaseURL: nil,
                openWeatherProxyConfigured: true
            )
        )
    }

    @Test func buildsTomTomAndOpenWeatherProxyURLs() throws {
        let base = URL(string: "http://127.0.0.1:8080")!
        let tomTom = try #require(
            ForecastRiskSampler.tomTomFlowProxyURL(
                fleetBaseURL: base,
                latitude: 52.63,
                longitude: 1.297
            )
        )
        #expect(tomTom.absoluteString.contains("/v1/proxy/tomtom/flow"))
        #expect(tomTom.absoluteString.contains("point=52.63,1.297"))

        let openWeather = try #require(
            ForecastRiskSampler.openWeatherForecastProxyURL(
                fleetBaseURL: base,
                latitude: 52.63,
                longitude: 1.297
            )
        )
        #expect(openWeather.absoluteString.contains("/v1/proxy/openweather/forecast"))
        #expect(openWeather.absoluteString.contains("lat=52.63"))
        #expect(openWeather.absoluteString.contains("lon=1.297"))
        #expect(openWeather.absoluteString.contains("cnt=8"))
    }
}
