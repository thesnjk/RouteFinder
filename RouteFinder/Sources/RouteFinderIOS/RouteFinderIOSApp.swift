#if os(macOS)
@main
enum RouteFinderIOSMacStub {
    static func main() {
        print("RouteFinderIOS is iOS-only. Use the RouteFinder target on macOS.")
    }
}
#elseif os(iOS)
import SwiftUI
import UI

@main
struct RouteFinderIOSApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var weatherViewModel = WeatherViewModel.makeDefault()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(weatherViewModel)
                .onAppear {
                    weatherViewModel.startMonitoring()
                }
        }
    }
}
#endif
