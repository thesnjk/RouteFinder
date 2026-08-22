import SharedCore
import Testing

struct WeatherConditionMappingTests {
    @Test func mapsSnowToIce() {
        #expect(WeatherConditionMapping.condition(description: "Snow", temperatureCelsius: 2) == .ice)
    }

    @Test func mapsRainToRain() {
        #expect(WeatherConditionMapping.condition(description: "Rain", temperatureCelsius: 8) == .rain)
    }

    @Test func mapsClearToDry() {
        #expect(WeatherConditionMapping.condition(description: "Clear", temperatureCelsius: 18) == .dry)
    }

    @Test func mapsFreezingTemperatureToIce() {
        #expect(WeatherConditionMapping.condition(description: "Clouds", temperatureCelsius: -2) == .ice)
    }
}
