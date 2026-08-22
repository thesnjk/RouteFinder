import Foundation

/// Maps vendor weather descriptions and temperature to surface conditions.
public enum WeatherConditionMapping: Sendable {
    /// Classifies a weather description and optional temperature into a routing surface condition.
    public static func condition(
        description: String?,
        temperatureCelsius: Double?
    ) -> WeatherCondition {
        let normalized = description?.lowercased() ?? ""
        if normalized.contains("snow")
            || normalized.contains("sleet")
            || normalized.contains("hail")
            || normalized.contains("freezing")
            || normalized.contains("blizzard")
            || normalized.contains("ice")
            || (temperatureCelsius.map { $0 <= 0 } ?? false) {
            return .ice
        }
        if normalized.contains("rain")
            || normalized.contains("drizzle")
            || normalized.contains("thunder")
            || normalized.contains("shower") {
            return .rain
        }
        return .dry
    }
}
