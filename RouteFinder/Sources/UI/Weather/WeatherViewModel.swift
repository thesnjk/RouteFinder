#if os(iOS)
import Contracts
import CoreLocation
import Foundation
import SharedCore

/// Monitors location and weather to drive automatic road condition selection with manual override support.
@MainActor
public final class WeatherViewModel: ObservableObject {
    @Published public private(set) var autoDetectedCondition: EnvironmentalContext = .dry
    @Published public private(set) var manualOverride: EnvironmentalContext?
    @Published public private(set) var effectiveCondition: EnvironmentalContext = .dry
    @Published public private(set) var isUpdating = false
    @Published public private(set) var lastError: String?

    public var isAutomatic: Bool { manualOverride == nil }

    private var weatherService: any WeatherService
    private let locationService: LocationService
    private var lastWeatherFetchLocation: CLLocation?
    private var fetchTask: Task<Void, Never>?
    private var isMonitoring = false
    private let weatherConfigurationObserver = FleetStoreConfigurationObserver()

    /// Creates a weather view model with injectable services.
    public init(
        weatherService: any WeatherService,
        locationService: LocationService
    ) {
        self.weatherService = weatherService
        self.locationService = locationService
        weatherConfigurationObserver.token = NotificationCenter.default.addObserver(
            forName: .weatherConfigurationDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.reloadPreferredWeatherService()
            }
        }
    }

    /// Creates a view model with the preferred live weather stack.
    ///
    /// Prefers OpenWeather when an API key is stored or set in the environment;
    /// otherwise uses WeatherKit (paid-team entitlement required at runtime).
    public static func makeDefault() -> WeatherViewModel {
        WeatherViewModel(
            weatherService: DefaultWeatherService.make(),
            locationService: LocationService()
        )
    }

    /// Swaps the live weather backend (e.g. after OpenWeather key save) and refetches if possible.
    public func replaceWeatherService(_ service: any WeatherService) {
        fetchTask?.cancel()
        fetchTask = nil
        weatherService = service
        lastError = nil
        let previous = lastWeatherFetchLocation
        lastWeatherFetchLocation = nil
        if let previous {
            fetchTask = Task { [weak self] in
                await self?.fetchWeather(at: previous)
            }
        }
    }

    /// Rebuilds the preferred backend from Settings / environment and applies it immediately.
    public func reloadPreferredWeatherService() {
        replaceWeatherService(DefaultWeatherService.make())
    }

    /// Begins location monitoring and weather refresh on significant movement.
    public func startMonitoring() {
        guard !isMonitoring else { return }
        isMonitoring = true
        locationService.onLocationUpdate = { [weak self] coordinate in
            Task { @MainActor in
                self?.handleLocationUpdate(coordinate)
            }
        }
        locationService.start()
    }

    /// Stops location monitoring and cancels in-flight weather requests.
    public func stopMonitoring() {
        isMonitoring = false
        locationService.onLocationUpdate = nil
        locationService.stop()
        fetchTask?.cancel()
        fetchTask = nil
    }

    /// Applies a user-selected road condition override.
    public func userSelect(_ condition: EnvironmentalContext) {
        manualOverride = condition
        publishEffectiveCondition()
    }

    /// Clears manual override and resumes automatic weather-based updates.
    public func useAutomatic() {
        manualOverride = nil
        publishEffectiveCondition()
    }

    #if DEBUG
    /// Simulates a location update for unit tests without starting Core Location.
    func processLocationUpdateForTesting(_ coordinate: CLLocationCoordinate2D) {
        handleLocationUpdate(coordinate)
    }
    #endif

    private func handleLocationUpdate(_ coordinate: CLLocationCoordinate2D) {
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        guard SignificantLocationGate.shouldFetch(from: lastWeatherFetchLocation, to: location) else {
            return
        }
        fetchTask?.cancel()
        fetchTask = Task { [weak self] in
            await self?.fetchWeather(at: location)
        }
    }

    private func fetchWeather(at location: CLLocation) async {
        isUpdating = true
        lastError = nil
        defer { isUpdating = false }

        let routingCoordinate = RoutingCoordinate(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude
        )

        do {
            let weather = try await weatherService.fetchCurrent(at: routingCoordinate)
            guard !Task.isCancelled else { return }
            lastWeatherFetchLocation = location
            autoDetectedCondition = weather.environmentalContext
            publishEffectiveCondition()
        } catch {
            guard !Task.isCancelled else { return }
            var message = error.localizedDescription
            if DefaultWeatherService.selectBackend() == .weatherKit {
                message += " — \(DefaultWeatherService.openWeatherSettingsHint)"
            }
            lastError = message
        }
    }

    private func publishEffectiveCondition() {
        effectiveCondition = manualOverride ?? autoDetectedCondition
    }
}
#endif
