// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.
//
// NOTE: Swift 6.2 is not yet released (as of mid-2026).
// If you encounter "unknown tools version" errors, dial this back to:
//    swift-tools-version: 6.0   (requires Xcode 16.0+)
// or swift-tools-version: 5.10  (requires Xcode 15.4+)

import PackageDescription

let package = Package(
    name: "RouteFinder",
    platforms: [
        .macOS(.v14),
        .iOS(.v17),
    ],

    products: [
        .library(name: "Contracts", targets: ["Contracts"]),
        .library(name: "GraphCore", targets: ["GraphCore"]),
        .library(name: "CostModel", targets: ["CostModel"]),
        .library(name: "DataLayer", targets: ["DataLayer"]),
        .library(name: "PathfindingEngine", targets: ["PathfindingEngine"]),
        .library(name: "RouteController", targets: ["RouteController"]),
        .library(name: "NavigationCore", targets: ["NavigationCore"]),
        .library(name: "MapLibreUI", targets: ["MapLibreUI"]),
        .library(name: "CarPlayUI", targets: ["CarPlayUI"]),
        .library(name: "UI", targets: ["UI"]),
        .library(name: "SharedCore", targets: ["SharedCore"]),
        .executable(name: "RouteFinder", targets: ["CLI"]),
        .executable(name: "CLI", targets: ["CLI"]),
        .executable(name: "RouteFinderMacApp", targets: ["RouteFinderMacApp"]),
        .executable(name: "RouteFinderIOS", targets: ["RouteFinderIOS"]),
        .executable(name: "PBFPreprocessor", targets: ["PBFPreprocessor"]),
        .executable(name: "RouteFinderFleetServer", targets: ["RouteFinderFleetServer"]),
    ],

    // ── Apple Collection & Algorithm Packages ──────────────
    // swift-collections gives us high-performance Heap (priority queue)
    // swift-algorithms adds utilities for sequence chunking etc.
    dependencies: [
        .package(
            url: "https://github.com/apple/swift-collections.git",
            from: "1.1.0"
        ),
        .package(
            url: "https://github.com/apple/swift-algorithms.git",
            from: "1.2.0"
        ),
        .package(
            url: "https://github.com/apple/swift-testing.git",
            exact: "0.99.0"
        ),
        .package(
            url: "https://github.com/hummingbird-project/hummingbird.git",
            from: "2.0.0"
        ),
    ],

    // ── Target Hierarchy (matches agent dependency graph) ──
    targets: [

        // ══════════════════════════════════════════════════════
        // Agent 0 — Shared Contracts (zero dependencies)
        // ══════════════════════════════════════════════════════
        .target(
            name: "Contracts",
            dependencies: []
        ),

        // ══════════════════════════════════════════════════════
        // Navigation Core — headless route progress & geometry
        // ══════════════════════════════════════════════════════
        .target(
            name: "NavigationCore",
            dependencies: [
                "Contracts",
                "CostModel",
            ]
        ),

        // ══════════════════════════════════════════════════════
        // MapLibre UI — OSM map canvas (WKWebView + MapLibre GL JS)
        // ══════════════════════════════════════════════════════
        .target(
            name: "MapLibreUI",
            dependencies: [
                "RouteController",
                "NavigationCore",
            ]
        ),

        // ══════════════════════════════════════════════════════
        // CarPlay UI — CarPlay template integration (iOS)
        // ══════════════════════════════════════════════════════
        .target(
            name: "CarPlayUI",
            dependencies: [
                "Contracts",
                "NavigationCore",
                "RouteController",
            ]
        ),

        // ══════════════════════════════════════════════════════
        // Agent 1 — Core Graph & Data Structures
        // ══════════════════════════════════════════════════════
        .target(
            name: "GraphCore",
            dependencies: [
                "Contracts",
                .product(name: "Collections",    package: "swift-collections"),
                .product(name: "Algorithms",     package: "swift-algorithms"),
            ]
        ),

        // ══════════════════════════════════════════════════════
        // Agent 3 — Cost Model & Constraints
        // ══════════════════════════════════════════════════════
        .target(
            name: "CostModel",
            dependencies: [
                "Contracts",
            ]
        ),

        // ══════════════════════════════════════════════════════
        // Agent 6 — Data Layer & Persistence
        // ══════════════════════════════════════════════════════
        .target(
            name: "DataLayer",
            dependencies: [
                "Contracts",
                "GraphCore",
                "CostModel",
            ]
        ),

        // ══════════════════════════════════════════════════════
        // Agent 2 — Pathfinding Algorithms
        // ══════════════════════════════════════════════════════
        .target(
            name: "PathfindingEngine",
            dependencies: [
                "Contracts",
                "GraphCore",
                "CostModel",
                .product(name: "Collections",    package: "swift-collections"),
            ]
        ),

        // ══════════════════════════════════════════════════════
        // Agent 4 — Route Planning Controller
        // ══════════════════════════════════════════════════════
        .target(
            name: "RouteController",
            dependencies: [
                "Contracts",
                "GraphCore",
                "CostModel",
                "PathfindingEngine",
                "DataLayer",
            ]
        ),

        // ══════════════════════════════════════════════════════
        // Agent 5 — UI / Liquid Glass Design System
        // ══════════════════════════════════════════════════════
        .target(
            name: "UI",
            dependencies: [
                "Contracts",
                "SharedCore",
                "GraphCore",
                "CostModel",
                "PathfindingEngine",
                "RouteController",
                "DataLayer",
                "MapLibreUI",
                "NavigationCore",
            ]
        ),

        // ══════════════════════════════════════════════════════
        // Shared core — weather and cross-platform routing helpers
        // ══════════════════════════════════════════════════════
        .target(
            name: "SharedCore",
            dependencies: [
                "Contracts",
                "DataLayer",
            ]
        ),

        // ══════════════════════════════════════════════════════
        // Headless CLI — macOS terminal routing (no UI)
        // ══════════════════════════════════════════════════════
        .executableTarget(
            name: "CLI",
            dependencies: [
                "SharedCore",
                "RouteController",
                "DataLayer",
                "Contracts",
                "GraphCore",
            ]
        ),

        // ══════════════════════════════════════════════════════
        // macOS GUI app — SwiftUI windowed experience
        // ══════════════════════════════════════════════════════
        .executableTarget(
            name: "RouteFinderMacApp",
            dependencies: [
                "UI",
            ],
            exclude: ["Info.plist"]
        ),

        // ══════════════════════════════════════════════════════
        // iOS app entry point
        // ══════════════════════════════════════════════════════
        .executableTarget(
            name: "RouteFinderIOS",
            dependencies: [
                "UI",
                "CarPlayUI",
            ],
            exclude: ["Info.plist", "RouteFinderIOS.entitlements", "RouteFinderIOS.carplay.entitlements"]
        ),

        .executableTarget(
            name: "PBFPreprocessor",
            dependencies: [
                "DataLayer",
                "GraphCore",
            ]
        ),

        .target(
            name: "FleetServerCore",
            dependencies: [
                "Contracts",
                "DataLayer",
                .product(name: "Hummingbird", package: "hummingbird"),
                .product(name: "HummingbirdTLS", package: "hummingbird"),
            ]
        ),

        .executableTarget(
            name: "RouteFinderFleetServer",
            dependencies: [
                "FleetServerCore",
                "DataLayer",
                .product(name: "Hummingbird", package: "hummingbird"),
                .product(name: "HummingbirdTLS", package: "hummingbird"),
            ]
        ),

        // ══════════════════════════════════════════════════════
        // Test targets (one per module)
        // ══════════════════════════════════════════════════════
        .testTarget(
            name: "GraphCoreTests",
            dependencies: [
                "GraphCore",
                "UI",
                .product(name: "Testing", package: "swift-testing"),
            ]
        ),
        .testTarget(
            name: "CostModelTests",
            dependencies: [
                "CostModel",
                .product(name: "Testing", package: "swift-testing"),
            ]
        ),
        .testTarget(
            name: "DataLayerTests",
            dependencies: [
                "DataLayer",
                "CostModel",
                "RouteController",
                "FleetServerCore",
                .product(name: "Hummingbird", package: "hummingbird"),
                .product(name: "Testing", package: "swift-testing"),
            ]
        ),
        .testTarget(
            name: "PathfindingEngineTests",
            dependencies: [
                "PathfindingEngine",
                .product(name: "Testing", package: "swift-testing"),
            ]
        ),
        .testTarget(
            name: "RouteControllerTests",
            dependencies: [
                "RouteController",
                .product(name: "Testing", package: "swift-testing"),
            ]
        ),
        .testTarget(
            name: "UITests",
            dependencies: [
                "UI",
                "DataLayer",
                .product(name: "Testing", package: "swift-testing"),
            ]
        ),
        .testTarget(
            name: "MapLibreUITests",
            dependencies: [
                "MapLibreUI",
                .product(name: "Testing", package: "swift-testing"),
            ]
        ),
        .testTarget(
            name: "NavigationCoreTests",
            dependencies: [
                "NavigationCore",
                .product(name: "Testing", package: "swift-testing"),
            ]
        ),
        .testTarget(
            name: "CarPlayUITests",
            dependencies: [
                "CarPlayUI",
                .product(name: "Testing", package: "swift-testing"),
            ]
        ),
        .testTarget(
            name: "SharedCoreTests",
            dependencies: [
                "SharedCore",
                .product(name: "Testing", package: "swift-testing"),
            ]
        ),
    ]
)
