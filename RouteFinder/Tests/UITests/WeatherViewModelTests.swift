#if os(iOS)
import Contracts
import CoreLocation
import SharedCore
import Testing
@testable import UI

private struct MockWeatherService: WeatherService {
    var result: WeatherCondition = .rain
    var thrownError: Error?

    func fetchCurrent(at location: RoutingCoordinate) async throws -> WeatherCondition {
        if let thrownError {
            throw thrownError
        }
        _ = location
        return result
    }
}

struct WeatherViewModelTests {
    @Test @MainActor func manualOverrideBlocksEffectiveConditionChanges() async {
        let weather = MockWeatherService(result: .dry)
        let locationService = LocationService()
        let viewModel = WeatherViewModel(weatherService: weather, locationService: locationService)

        viewModel.userSelect(.ice)
        #expect(viewModel.effectiveCondition == .ice)
        #expect(!viewModel.isAutomatic)

        viewModel.processLocationUpdateForTesting(CLLocationCoordinate2D(latitude: 51.5, longitude: -0.12))
        try? await Task.sleep(for: .milliseconds(200))

        #expect(viewModel.effectiveCondition == .ice)
    }

    @Test @MainActor func automaticModeUpdatesEffectiveCondition() async {
        let weather = MockWeatherService(result: .rain)
        let locationService = LocationService()
        let viewModel = WeatherViewModel(weatherService: weather, locationService: locationService)

        viewModel.processLocationUpdateForTesting(CLLocationCoordinate2D(latitude: 51.5, longitude: -0.12))
        try? await Task.sleep(for: .milliseconds(300))

        #expect(viewModel.isAutomatic)
        #expect(viewModel.effectiveCondition == .rain)
    }

    @Test @MainActor func useAutomaticRestoresWeatherCondition() async {
        let weather = MockWeatherService(result: .rain)
        let locationService = LocationService()
        let viewModel = WeatherViewModel(weatherService: weather, locationService: locationService)

        viewModel.processLocationUpdateForTesting(CLLocationCoordinate2D(latitude: 51.5, longitude: -0.12))
        try? await Task.sleep(for: .milliseconds(300))
        viewModel.userSelect(.ice)
        viewModel.useAutomatic()

        #expect(viewModel.isAutomatic)
        #expect(viewModel.effectiveCondition == .rain)
    }

    @Test @MainActor func replaceWeatherServiceRefetchesWithNewBackend() async {
        let first = MockWeatherService(result: .dry)
        let second = MockWeatherService(result: .rain)
        let locationService = LocationService()
        let viewModel = WeatherViewModel(weatherService: first, locationService: locationService)

        viewModel.processLocationUpdateForTesting(CLLocationCoordinate2D(latitude: 51.5, longitude: -0.12))
        try? await Task.sleep(for: .milliseconds(300))
        #expect(viewModel.effectiveCondition == .dry)

        viewModel.replaceWeatherService(second)
        try? await Task.sleep(for: .milliseconds(300))
        #expect(viewModel.effectiveCondition == .rain)
        #expect(viewModel.lastError == nil)
    }
}
#endif
