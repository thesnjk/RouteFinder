import SharedCore
import Testing

@Suite("Default weather service selection")
struct DefaultWeatherServiceTests {
    @Test("Prefers OpenWeather when an explicit key is present")
    func prefersOpenWeatherWithExplicitKey() {
        let backend = DefaultWeatherService.selectBackend(
            openWeatherAPIKey: "abc123",
            environmentKey: nil,
            storedKey: nil
        )
        #expect(backend == .openWeather)
    }

    @Test("Prefers OpenWeather when the environment key is present")
    func prefersOpenWeatherWithEnvironmentKey() {
        let backend = DefaultWeatherService.selectBackend(
            openWeatherAPIKey: nil,
            environmentKey: "env-key",
            storedKey: nil
        )
        #expect(backend == .openWeather)
    }

    @Test("Prefers OpenWeather when a stored key is present")
    func prefersOpenWeatherWithStoredKey() {
        let backend = DefaultWeatherService.selectBackend(
            openWeatherAPIKey: nil,
            environmentKey: nil,
            storedKey: "stored-key"
        )
        #expect(backend == .openWeather)
    }

    @Test("Falls back to WeatherKit when no OpenWeather key is available")
    func fallsBackToWeatherKitWithoutKey() {
        let backend = DefaultWeatherService.selectBackend(
            openWeatherAPIKey: "   ",
            environmentKey: "",
            storedKey: nil
        )
        #expect(backend == .weatherKit)
    }
}
