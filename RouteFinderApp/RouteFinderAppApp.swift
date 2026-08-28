//
//  RouteFinderAppApp.swift
//  RouteFinderApp
//
//  Created by Jacob on 05/07/2026.
//

import SwiftUI
import UI

@main
struct RouteFinderAppApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var weatherViewModel = WeatherViewModel.makeDefault()

    var body: some Scene {
        WindowGroup {
            RootAuthContainer()
                .environmentObject(weatherViewModel)
        }
    }
}
