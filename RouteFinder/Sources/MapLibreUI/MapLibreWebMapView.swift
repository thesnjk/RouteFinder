import CoreLocation
import CryptoKit
import RouteController
import SwiftUI
import WebKit

#if os(macOS)
import AppKit
#else
import UIKit
#endif

/// Simulated vehicle position for route playback on the map.
public struct SimulatedVehicleState: Equatable, Sendable {
    public let latitude: Double
    public let longitude: Double
    public let bearing: Double
    public let visible: Bool
    public let lengthMeters: Double
    public let widthMeters: Double
    public let playbackRevision: UInt64
    public let dimensionRevision: UInt64
    public let renderMode: VehicleRenderMode
    public let footprintCoordinates: [CLLocationCoordinate2D]
    /// Optional multi-part footprint rings (tractor + trailer, etc.).
    public let footprintParts: [[CLLocationCoordinate2D]]
    /// Whether the rendered vehicle is a passenger car.
    public let isPassengerCar: Bool
    /// Wheelbase used for footprint / Ackermann helpers.
    public let wheelbaseMeters: Double

    /// Creates simulated vehicle state for the map bridge.
    public init(
        latitude: Double,
        longitude: Double,
        bearing: Double,
        visible: Bool,
        lengthMeters: Double = SimulatedVehicleFootprint.defaultLengthMeters,
        widthMeters: Double = SimulatedVehicleFootprint.defaultWidthMeters,
        playbackRevision: UInt64 = 0,
        dimensionRevision: UInt64 = 0,
        renderMode: VehicleRenderMode = .polygon,
        footprintCoordinates: [CLLocationCoordinate2D] = [],
        footprintParts: [[CLLocationCoordinate2D]] = [],
        isPassengerCar: Bool = false,
        wheelbaseMeters: Double = 6.5
    ) {
        self.latitude = latitude
        self.longitude = longitude
        self.bearing = bearing
        self.visible = visible
        self.lengthMeters = lengthMeters
        self.widthMeters = widthMeters
        self.playbackRevision = playbackRevision
        self.dimensionRevision = dimensionRevision
        self.renderMode = renderMode
        self.footprintParts = footprintParts
        self.isPassengerCar = isPassengerCar
        self.wheelbaseMeters = wheelbaseMeters
        if visible, footprintCoordinates.isEmpty {
            self.footprintCoordinates = VehicleGeometryCalculator.generateFootprint(
                rearAxle: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
                headingDegrees: bearing,
                lengthMeters: lengthMeters,
                widthMeters: widthMeters
            )
        } else {
            self.footprintCoordinates = footprintCoordinates
        }
    }

    public static func == (lhs: SimulatedVehicleState, rhs: SimulatedVehicleState) -> Bool {
        lhs.latitude == rhs.latitude
            && lhs.longitude == rhs.longitude
            && lhs.bearing == rhs.bearing
            && lhs.visible == rhs.visible
            && lhs.lengthMeters == rhs.lengthMeters
            && lhs.widthMeters == rhs.widthMeters
            && lhs.playbackRevision == rhs.playbackRevision
            && lhs.dimensionRevision == rhs.dimensionRevision
            && lhs.renderMode == rhs.renderMode
            && lhs.isPassengerCar == rhs.isPassengerCar
            && lhs.wheelbaseMeters == rhs.wheelbaseMeters
            && lhs.footprintCoordinates.count == rhs.footprintCoordinates.count
            && zip(lhs.footprintCoordinates, rhs.footprintCoordinates).allSatisfy {
                $0.latitude == $1.latitude && $0.longitude == $1.longitude
            }
            && lhs.footprintParts.count == rhs.footprintParts.count
    }
}

/// MapLibre GL JS map embedded in WKWebView with OpenFreeMap tiles.
public struct MapLibreWebMapView: View {
    let coordinates: [CLLocationCoordinate2D]
    let encodedPolyline: String?
    let encodedPolylinePrecision: Int
    let routeCumulativeLengths: [Double]
    let pins: [MapLibrePin]
    let hazardsGeoJSON: String
    let simulatedVehicle: SimulatedVehicleState?
    let interactionMode: MapLibreInteractionMode
    let region: MapRegion
    /// MapLibre style URL (CDN, `http://127.0.0.1`, or `routefinder-tiles://`).
    let styleURL: String
    /// BCP-47 language code for basemap symbol labels.
    let labelLanguage: String
    /// OSM `name:*` property keys passed to MapLibre coalesce expressions.
    let labelNameCandidates: [String]
    let mapBridge: MapViewControllerBridge?
    let onMapClick: (CLLocationCoordinate2D) -> Void
    let onContextMenu: (CLLocationCoordinate2D) -> Void
    let onRegionChange: (CLLocationCoordinate2D) -> Void
    let loadState: MapWebViewLoadState?
    let onRetryMapLoad: (() -> Void)?
    let onUseOnlineMap: (() -> Void)?

    public init(
        coordinates: [CLLocationCoordinate2D],
        encodedPolyline: String? = nil,
        encodedPolylinePrecision: Int = 6,
        routeCumulativeLengths: [Double] = [],
        pins: [MapLibrePin] = [],
        hazardsGeoJSON: String = "{\"type\":\"FeatureCollection\",\"features\":[]}",
        simulatedVehicle: SimulatedVehicleState? = nil,
        interactionMode: MapLibreInteractionMode = .navigate,
        region: MapRegion,
        styleURL: String = MapLibreConfiguration.openFreeMapStyleURL,
        labelLanguage: String = "en",
        labelNameCandidates: [String] = ["name:en", "name", "name:latin"],
        mapBridge: MapViewControllerBridge? = nil,
        onMapClick: @escaping (CLLocationCoordinate2D) -> Void = { _ in },
        onContextMenu: @escaping (CLLocationCoordinate2D) -> Void = { _ in },
        onRegionChange: @escaping (CLLocationCoordinate2D) -> Void = { _ in },
        loadState: MapWebViewLoadState? = nil,
        onRetryMapLoad: (() -> Void)? = nil,
        onUseOnlineMap: (() -> Void)? = nil
    ) {
        self.coordinates = coordinates
        self.encodedPolyline = encodedPolyline
        self.encodedPolylinePrecision = encodedPolylinePrecision
        self.routeCumulativeLengths = routeCumulativeLengths
        self.pins = pins
        self.hazardsGeoJSON = hazardsGeoJSON
        self.simulatedVehicle = simulatedVehicle
        self.interactionMode = interactionMode
        self.region = region
        self.styleURL = styleURL
        self.labelLanguage = labelLanguage
        self.labelNameCandidates = labelNameCandidates
        self.mapBridge = mapBridge
        self.onMapClick = onMapClick
        self.onContextMenu = onContextMenu
        self.onRegionChange = onRegionChange
        self.loadState = loadState
        self.onRetryMapLoad = onRetryMapLoad
        self.onUseOnlineMap = onUseOnlineMap
    }

    public var body: some View {
        MapLibreWebMapContainer(
            coordinates: coordinates,
            encodedPolyline: encodedPolyline,
            encodedPolylinePrecision: encodedPolylinePrecision,
            routeCumulativeLengths: routeCumulativeLengths,
            pins: pins,
            hazardsGeoJSON: hazardsGeoJSON,
            simulatedVehicle: simulatedVehicle,
            interactionMode: interactionMode,
            region: region,
            styleURL: styleURL,
            labelLanguage: labelLanguage,
            labelNameCandidates: labelNameCandidates,
            mapBridge: mapBridge,
            onMapClick: onMapClick,
            onContextMenu: onContextMenu,
            onRegionChange: onRegionChange,
            externalLoadState: loadState,
            onRetryMapLoad: onRetryMapLoad,
            onUseOnlineMap: onUseOnlineMap
        )
    }
}

private struct MapLibreWebMapContainer: View {
    let coordinates: [CLLocationCoordinate2D]
    let encodedPolyline: String?
    let encodedPolylinePrecision: Int
    let routeCumulativeLengths: [Double]
    let pins: [MapLibrePin]
    let hazardsGeoJSON: String
    let simulatedVehicle: SimulatedVehicleState?
    let interactionMode: MapLibreInteractionMode
    let region: MapRegion
    let styleURL: String
    let labelLanguage: String
    let labelNameCandidates: [String]
    let mapBridge: MapViewControllerBridge?
    let onMapClick: (CLLocationCoordinate2D) -> Void
    let onContextMenu: (CLLocationCoordinate2D) -> Void
    let onRegionChange: (CLLocationCoordinate2D) -> Void
    let externalLoadState: MapWebViewLoadState?
    let onRetryMapLoad: (() -> Void)?
    let onUseOnlineMap: (() -> Void)?

    @State private var internalLoadState = MapWebViewLoadState()
    @State private var reloadToken = 0

    private var loadState: MapWebViewLoadState {
        externalLoadState ?? internalLoadState
    }

    var body: some View {
        ZStack {
            MapLibreWebViewRepresentable(
                coordinates: coordinates,
                encodedPolyline: encodedPolyline,
                encodedPolylinePrecision: encodedPolylinePrecision,
                routeCumulativeLengths: routeCumulativeLengths,
                pins: pins,
                hazardsGeoJSON: hazardsGeoJSON,
                simulatedVehicle: simulatedVehicle,
                interactionMode: interactionMode,
                region: region,
                styleURL: styleURL,
                labelLanguage: labelLanguage,
                labelNameCandidates: labelNameCandidates,
                mapBridge: mapBridge,
                onMapClick: onMapClick,
                onContextMenu: onContextMenu,
                onRegionChange: onRegionChange,
                loadState: loadState,
                reloadToken: reloadToken
            )
            .id(reloadToken)
            .ignoresSafeArea()

            if loadState.isLoading, loadState.errorMessage == nil {
                ProgressView("Loading map…")
                    .padding(16)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                    .accessibilityLabel("Loading map")
            }

            if let errorMessage = loadState.errorMessage {
                mapLoadErrorOverlay(message: errorMessage)
            }
        }
    }

    @ViewBuilder
    private func mapLoadErrorOverlay(message: String) -> some View {
        VStack(spacing: 12) {
            Text("Basemap failed to load")
                .font(.headline)
            Text(Self.userFacingBasemapMessage(message))
                .font(.caption)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Text("Routing uses HeiGIT ORS (Settings → API Keys) and is separate from map tiles.")
                .font(.caption2)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            HStack(spacing: 12) {
                Button("Retry") {
                    loadState.resetForReload()
                    reloadToken += 1
                    onRetryMapLoad?()
                }
                .buttonStyle(.borderedProminent)
                if onUseOnlineMap != nil {
                    Button("Use online map") {
                        loadState.resetForReload()
                        onUseOnlineMap?()
                        reloadToken += 1
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .padding(20)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .padding(20)
        .accessibilityElement(children: .combine)
    }

    private static func userFacingBasemapMessage(_ raw: String) -> String {
        let lowered = raw.lowercased()
        if lowered.contains("network") || lowered.contains("connection") || lowered.contains("offline") {
            return "OpenFreeMap basemap tiles could not be reached (\(raw)). Check Wi‑Fi or cellular, then Retry."
        }
        return raw
    }
}

/// Pin rendered on the MapLibre canvas.
public struct MapLibrePin: Identifiable, Sendable {
    public let id: String
    public let coordinate: CLLocationCoordinate2D
    public let colorHex: String
    public let title: String

    public init(id: String, coordinate: CLLocationCoordinate2D, colorHex: String, title: String) {
        self.id = id
        self.coordinate = coordinate
        self.colorHex = colorHex
        self.title = title
    }
}

/// Map interaction mode for pin placement vs navigation.
public enum MapLibreInteractionMode: Equatable, Sendable {
    case navigate
    case pin
}

#if os(macOS)
/// WKWebView subclass that does not capture keyboard focus, keeping text fields in sheets usable.
private final class MapKeyboardPassiveWebView: WKWebView {
    override var acceptsFirstResponder: Bool { false }
}

/// Hosts the WKWebView behind SwiftUI overlays so map chrome receives pointer events first.
private final class MapWebViewHost: NSView {
    let webView: WKWebView

    init(webView: WKWebView) {
        self.webView = webView
        super.init(frame: .zero)
        wantsLayer = true
        addSubview(webView)
        webView.wantsLayer = true
        webView.layer?.zPosition = -1
        webView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            webView.leadingAnchor.constraint(equalTo: leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: trailingAnchor),
            webView.topAnchor.constraint(equalTo: topAnchor),
            webView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

private struct MapLibreWebViewRepresentable: NSViewRepresentable {
    typealias PlatformWebView = WKWebView

    let coordinates: [CLLocationCoordinate2D]
    let encodedPolyline: String?
    let encodedPolylinePrecision: Int
    let routeCumulativeLengths: [Double]
    let pins: [MapLibrePin]
    let hazardsGeoJSON: String
    let simulatedVehicle: SimulatedVehicleState?
    let interactionMode: MapLibreInteractionMode
    let region: MapRegion
    let styleURL: String
    let labelLanguage: String
    let labelNameCandidates: [String]
    let mapBridge: MapViewControllerBridge?
    let onMapClick: (CLLocationCoordinate2D) -> Void
    let onContextMenu: (CLLocationCoordinate2D) -> Void
    let onRegionChange: (CLLocationCoordinate2D) -> Void
    let loadState: MapWebViewLoadState?
    let reloadToken: Int

    func makeNSView(context: Context) -> MapWebViewHost {
        let webView = MapKeyboardPassiveWebView(frame: .zero, configuration: context.coordinator.makeConfiguration())
        webView.setValue(false, forKey: "drawsBackground")
        webView.navigationDelegate = context.coordinator
        context.coordinator.webView = webView
        context.coordinator.loadMap(in: webView, region: region)
        return MapWebViewHost(webView: webView)
    }

    func updateNSView(_ host: MapWebViewHost, context: Context) {
        context.coordinator.parent = self
        context.coordinator.registerSimulationBridge()
        context.coordinator.syncState(to: host.webView)
    }

    func makeCoordinator() -> Coordinator {
        let coordinator = Coordinator(parent: self, loadState: loadState)
        coordinator.registerSimulationBridge()
        return coordinator
    }
}
#else
/// Hosts the WKWebView behind SwiftUI overlays so map chrome receives touches first.
private final class MapWebViewHostView: UIView {
    let webView: WKWebView

    init(webView: WKWebView) {
        self.webView = webView
        super.init(frame: .zero)
        addSubview(webView)
        webView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            webView.leadingAnchor.constraint(equalTo: leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: trailingAnchor),
            webView.topAnchor.constraint(equalTo: topAnchor),
            webView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
        webView.layer.zPosition = -1
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

private struct MapLibreWebViewRepresentable: UIViewRepresentable {
    typealias PlatformWebView = WKWebView

    let coordinates: [CLLocationCoordinate2D]
    let encodedPolyline: String?
    let encodedPolylinePrecision: Int
    let routeCumulativeLengths: [Double]
    let pins: [MapLibrePin]
    let hazardsGeoJSON: String
    let simulatedVehicle: SimulatedVehicleState?
    let interactionMode: MapLibreInteractionMode
    let region: MapRegion
    let styleURL: String
    let labelLanguage: String
    let labelNameCandidates: [String]
    let mapBridge: MapViewControllerBridge?
    let onMapClick: (CLLocationCoordinate2D) -> Void
    let onContextMenu: (CLLocationCoordinate2D) -> Void
    let onRegionChange: (CLLocationCoordinate2D) -> Void
    let loadState: MapWebViewLoadState?
    let reloadToken: Int

    func makeUIView(context: Context) -> MapWebViewHostView {
        let webView = WKWebView(frame: .zero, configuration: context.coordinator.makeConfiguration())
        webView.isOpaque = true
        webView.backgroundColor = .systemBackground
        webView.isMultipleTouchEnabled = true
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.delaysContentTouches = false
        webView.navigationDelegate = context.coordinator
        context.coordinator.webView = webView
        context.coordinator.loadMap(in: webView, region: region)
        return MapWebViewHostView(webView: webView)
    }

    func updateUIView(_ host: MapWebViewHostView, context: Context) {
        context.coordinator.parent = self
        context.coordinator.registerSimulationBridge()
        context.coordinator.syncState(to: host.webView)
    }

    func makeCoordinator() -> Coordinator {
        let coordinator = Coordinator(parent: self, loadState: loadState)
        coordinator.registerSimulationBridge()
        return coordinator
    }
}
#endif

private final class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
    var parent: MapLibreWebViewRepresentable
    weak var loadState: MapWebViewLoadState?
    weak var webView: WKWebView?
    private var isReady = false
    private var didInitMap = false
    private var lastStyleURL = ""
    private var lastRouteFingerprint = ""
    private var lastPinFingerprint = ""
    private var lastHazardsFingerprint = ""
    private var lastVehicleFingerprint = ""
    private var lastRegionFingerprint = ""
    private var lastLabelLanguageFingerprint = ""
    private var lastMode: MapLibreInteractionMode = .navigate
    private var suppressUserMoveEventCount = 0
    private var webContentTerminateReloadCount = 0
    private let maxWebContentTerminateReloads = 2
    private var styleNetworkRetryCount = 0
    private let maxStyleNetworkRetries = 1
    private let vehicleCoalescer = BridgeFrameCoalescer()

    private var shouldSuppressUserMoveEvents: Bool {
        suppressUserMoveEventCount > 0
    }

    private func beginSuppressUserMoveEvents(for durationMs: Int) {
        suppressUserMoveEventCount += 1
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(durationMs + 50))
            suppressUserMoveEventCount = max(0, suppressUserMoveEventCount - 1)
        }
    }

    init(parent: MapLibreWebViewRepresentable, loadState: MapWebViewLoadState?) {
        self.parent = parent
        self.loadState = loadState
    }

    func registerSimulationBridge() {
        parent.mapBridge?.easeToCenterHandler = { [weak self] lng, lat, zoom, durationMs in
            guard let self, let webView = self.webView else { return }
            self.beginSuppressUserMoveEvents(for: durationMs)
            if let zoom {
                webView.evaluateJavaScript(
                    "easeToCenter(\(lng), \(lat), \(zoom), \(durationMs))"
                )
            } else {
                webView.evaluateJavaScript(
                    "easeToCenter(\(lng), \(lat), null, \(durationMs))"
                )
            }
        }

        parent.mapBridge?.easeToNavigationHandler = { [weak self] command in
            guard let self, let webView = self.webView else { return }
            self.beginSuppressUserMoveEvents(for: command.durationMs)
            let zoomArg = command.zoom.map { String($0) } ?? "null"
            let bearingArg = command.bearing.map { String($0) } ?? "null"
            let pitchArg = command.pitch.map { String($0) } ?? "null"
            webView.evaluateJavaScript(
                "easeToNavigation(\(command.longitude), \(command.latitude), \(zoomArg), \(bearingArg), \(pitchArg), \(command.durationMs))"
            )
        }

        parent.mapBridge?.fitRouteBoundsHandler = { [weak self] padding in
            guard let self, let webView = self.webView else { return }
            self.beginSuppressUserMoveEvents(for: 850)
            webView.evaluateJavaScript(
                "fitRouteBounds({ top: \(padding.top), bottom: \(padding.bottom), left: \(padding.leading), right: \(padding.trailing) })"
            )
        }

        parent.mapBridge?.zoomByHandler = { [weak self] delta in
            guard let self, let webView = self.webView else { return }
            webView.evaluateJavaScript("zoomBy(\(delta))")
        }

        parent.mapBridge?.setZoomHandler = { [weak self] zoom in
            guard let self, let webView = self.webView else { return }
            webView.evaluateJavaScript("setZoom(\(zoom))")
        }

        NavigationMapBridge.shared.pushVehicle = { [weak self] state in
            guard let self, let webView = self.webView else { return }
            let renderMode = self.parent.mapBridge?.renderMode(
                for: self.parent.mapBridge?.currentMapZoom ?? MapViewControllerBridge.lodZoomThreshold
            ) ?? state.renderMode
            var enriched = state
            if renderMode != state.renderMode {
                enriched = SimulatedVehicleState(
                    latitude: state.latitude,
                    longitude: state.longitude,
                    bearing: state.bearing,
                    visible: state.visible,
                    lengthMeters: state.lengthMeters,
                    widthMeters: state.widthMeters,
                    playbackRevision: state.playbackRevision,
                    dimensionRevision: state.dimensionRevision,
                    renderMode: renderMode,
                    footprintCoordinates: state.footprintCoordinates,
                    footprintParts: state.footprintParts,
                    isPassengerCar: state.isPassengerCar,
                    wheelbaseMeters: state.wheelbaseMeters
                )
            }
            self.enqueueVehicleBridgeUpdate(enriched, to: webView)
            if state.visible {
                self.parent.mapBridge?.vehicleDidUpdate(
                    coordinate: CLLocationCoordinate2D(latitude: state.latitude, longitude: state.longitude),
                    bearing: state.bearing,
                    dimensions: VehicleMapDimensions(
                        lengthMeters: state.lengthMeters,
                        widthMeters: state.widthMeters
                    )
                )
            }
        }

        NavigationMapBridge.shared.pushRouteProgress = { [weak self] progress in
            guard let self, let webView = self.webView else { return }
            webView.evaluateJavaScript("setRouteProgress(\(progress.progressFraction))")
        }

        NavigationMapBridge.shared.pushRouteSplit = { [weak self] split in
            guard let self, let webView = self.webView else { return }
            let traveledJSON = split.traversedPath
                .map { "[\($0.longitude), \($0.latitude)]" }
                .joined(separator: ", ")
            let remainingJSON = split.remainingPath
                .map { "[\($0.longitude), \($0.latitude)]" }
                .joined(separator: ", ")
            webView.evaluateJavaScript(
                "applyRouteSplitLayers([\(traveledJSON)], [\(remainingJSON)])"
            )
        }

        NavigationMapBridge.shared.loadRouteGeometry = { [weak self] coordinates, cumulativeLengths, totalLength in
            guard let self, let webView = self.webView else { return }
            let coordsJSON = coordinates.map { "[\($0.longitude), \($0.latitude)]" }.joined(separator: ", ")
            let cumulativeJSON = cumulativeLengths.map { String($0) }.joined(separator: ", ")
            webView.evaluateJavaScript(
                "loadRouteGeometry([\(coordsJSON)], [\(cumulativeJSON)], \(totalLength))"
            )
        }

        NavigationMapBridge.shared.beginRouteReveal = { [weak self] coordinates, _, cumulativeLengths in
            guard let self, let webView = self.webView else { return }
            let coordsJSON = coordinates.map { "[\($0.longitude), \($0.latitude)]" }.joined(separator: ", ")
            let cumulativeJSON = cumulativeLengths.map { String($0) }.joined(separator: ", ")
            webView.evaluateJavaScript(
                "animateRouteReveal([\(coordsJSON)], [\(cumulativeJSON)], 1200)"
            )
        }
    }

    func makeConfiguration() -> WKWebViewConfiguration {
        let config = WKWebViewConfiguration()
        config.defaultWebpagePreferences.allowsContentJavaScript = true
        config.userContentController.add(self, name: "mapBridge")
        return config
    }

    func loadMap(in webView: WKWebView, region: MapRegion) {
        isReady = false
        didInitMap = false
        lastStyleURL = ""
        lastRouteFingerprint = ""
        lastPinFingerprint = ""
        lastHazardsFingerprint = ""
        lastVehicleFingerprint = ""
        lastRegionFingerprint = ""
        lastLabelLanguageFingerprint = ""
        Task { @MainActor in
            loadState?.resetForReload()
        }
        let loadParameters = MapLibreConfiguration.mapLoadParameters(styleURL: parent.styleURL)
        #if os(iOS)
        if loadParameters.iosUsesBootstrapServer {
            Task { [weak self, weak webView] in
                guard let self, let webView else { return }
                do {
                    let pageURL = try await MapBootstrapServer.shared.mapPageURL(html: loadParameters.html)
                    webView.load(URLRequest(url: pageURL))
                } catch {
                    await MainActor.run {
                        self.loadState?.markFailed(error.localizedDescription)
                    }
                }
            }
        } else {
            webView.loadHTMLString(loadParameters.html, baseURL: loadParameters.baseURL)
        }
        #else
        webView.loadHTMLString(loadParameters.html, baseURL: loadParameters.baseURL)
        #endif
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        guard !didInitMap else { return }
        didInitMap = true
        lastStyleURL = parent.styleURL
        let controlPosition = "top-right"
        let escapedStyle = escapeJS(parent.styleURL)
        webView.evaluateJavaScript(
            "bootMap([\(parent.region.center.longitude), \(parent.region.center.latitude)], \(parent.region.zoomLevel), '\(escapedStyle)', '\(controlPosition)')"
        )
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        handleNativeNavigationFailure(webView: webView, error: error)
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        handleNativeNavigationFailure(webView: webView, error: error)
    }

    private func handleNativeNavigationFailure(webView: WKWebView, error: Error) {
        let message = error.localizedDescription
        if shouldAutoRetryStyleLoad(message: message) {
            styleNetworkRetryCount += 1
            Task { @MainActor in
                loadState?.resetForReload()
            }
            reloadMap(in: webView)
            return
        }
        Task { @MainActor in
            loadState?.markFailed(message)
        }
    }

    private func shouldAutoRetryStyleLoad(message: String) -> Bool {
        guard styleNetworkRetryCount < maxStyleNetworkRetries else { return false }
        let lowered = message.lowercased()
        return lowered.contains("network")
            || lowered.contains("connection")
            || lowered.contains("offline")
            || lowered.contains("timed out")
            || lowered.contains("timeout")
    }

    #if os(iOS)
    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        if webContentTerminateReloadCount >= maxWebContentTerminateReloads {
            Task { @MainActor in
                loadState?.markFailed("Map process terminated repeatedly")
            }
            return
        }
        webContentTerminateReloadCount += 1
        Task { @MainActor in
            loadState?.markFailed("Map process terminated")
        }
        reloadMap(in: webView)
    }
    #endif

    private func reloadMap(in webView: WKWebView) {
        loadMap(in: webView, region: parent.region)
    }

    func syncState(to webView: WKWebView) {
        syncStyleURL(to: webView)
        guard isReady else { return }

        let routeFingerprint = routeFingerprint(
            coordinates: parent.coordinates,
            encodedPolyline: parent.encodedPolyline,
            precision: parent.encodedPolylinePrecision
        )
        if routeFingerprint != lastRouteFingerprint {
            lastRouteFingerprint = routeFingerprint
            if !parent.routeCumulativeLengths.isEmpty, parent.coordinates.count >= 2 {
                let coordsJSON = parent.coordinates.map { "[\($0.longitude), \($0.latitude)]" }.joined(separator: ", ")
                let cumulativeJSON = parent.routeCumulativeLengths.map { String($0) }.joined(separator: ", ")
                let total = parent.routeCumulativeLengths.last ?? 0
                webView.evaluateJavaScript(
                    "loadRouteGeometry([\(coordsJSON)], [\(cumulativeJSON)], \(total))"
                )
            } else if let encoded = parent.encodedPolyline, !encoded.isEmpty {
                let escaped = escapeJS(encoded)
                webView.evaluateJavaScript("setRouteEncoded('\(escaped)', \(parent.encodedPolylinePrecision))")
            } else {
                let coordsJSON = parent.coordinates.map { "[\($0.longitude), \($0.latitude)]" }.joined(separator: ", ")
                let cumulativeJSON = parent.routeCumulativeLengths.map { String($0) }.joined(separator: ", ")
                if parent.routeCumulativeLengths.isEmpty {
                    webView.evaluateJavaScript("setRoute([\(coordsJSON)])")
                } else {
                    webView.evaluateJavaScript("setRoute([\(coordsJSON)], [\(cumulativeJSON)])")
                }
            }
        }

        let pinFingerprint = parent.pins.map(\.id).joined(separator: "|")
        if pinFingerprint != lastPinFingerprint {
            lastPinFingerprint = pinFingerprint
            let markersJSON = parent.pins.map {
                "{ lng: \($0.coordinate.longitude), lat: \($0.coordinate.latitude), color: '\($0.colorHex)', title: '\(escapeJS($0.title))' }"
            }.joined(separator: ", ")
            webView.evaluateJavaScript("setMarkers([\(markersJSON)])")
        }

        let hazardsFingerprint = String(parent.hazardsGeoJSON.hashValue)
        if hazardsFingerprint != lastHazardsFingerprint {
            lastHazardsFingerprint = hazardsFingerprint
            let literal = jsonStringLiteral(parent.hazardsGeoJSON)
            webView.evaluateJavaScript("setHazards(JSON.parse(\(literal)))")
        }

        syncSimulatedVehicle(to: webView)

        let regionFingerprint = "\(parent.region.center.latitude)-\(parent.region.center.longitude)-\(parent.region.zoomLevel)"
        if regionFingerprint != lastRegionFingerprint {
            lastRegionFingerprint = regionFingerprint
            beginSuppressUserMoveEvents(for: 950)
            webView.evaluateJavaScript(
                "flyTo([\(parent.region.center.longitude), \(parent.region.center.latitude)], \(parent.region.zoomLevel))"
            )
        }

        if parent.interactionMode != lastMode {
            lastMode = parent.interactionMode
            let mode = parent.interactionMode == .pin ? "pin" : "navigate"
            webView.evaluateJavaScript("setInteractionMode('\(mode)')")
        }

        syncMapLabelLanguage(to: webView)
    }

    private func syncStyleURL(to webView: WKWebView) {
        guard parent.styleURL != lastStyleURL else { return }
        let escapedStyle = escapeJS(parent.styleURL)
        lastStyleURL = parent.styleURL
        if isReady {
            Task { @MainActor in
                loadState?.resetForReload()
            }
            isReady = false
            webView.evaluateJavaScript("setMapStyle('\(escapedStyle)')")
        } else if didInitMap {
            webView.evaluateJavaScript("setMapStyle('\(escapedStyle)')")
        }
    }

    private func syncMapLabelLanguage(to webView: WKWebView) {
        let fingerprint = "\(parent.labelLanguage)|\(parent.labelNameCandidates.joined(separator: ","))"
        guard fingerprint != lastLabelLanguageFingerprint else { return }
        lastLabelLanguageFingerprint = fingerprint
        let candidatesJSON = parent.labelNameCandidates
            .map { "'\(escapeJS($0))'" }
            .joined(separator: ", ")
        webView.evaluateJavaScript(
            "setMapLabelLanguage('\(escapeJS(parent.labelLanguage))', [\(candidatesJSON)])"
        )
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let body = message.body as? [String: Any],
              let type = body["type"] as? String else { return }

        switch type {
        case "ready":
            isReady = true
            webContentTerminateReloadCount = 0
            styleNetworkRetryCount = 0
            Task { @MainActor in
                loadState?.markReady()
            }
            webView.flatMap { syncState(to: $0) }
        case "error":
            let message = body["message"] as? String ?? "Map failed to load"
            if shouldAutoRetryStyleLoad(message: message), let webView {
                styleNetworkRetryCount += 1
                Task { @MainActor in
                    loadState?.resetForReload()
                }
                reloadMap(in: webView)
                return
            }
            isReady = false
            Task { @MainActor in
                loadState?.markFailed(message)
            }
        case "click":
            guard let lng = body["lng"] as? Double, let lat = body["lat"] as? Double else { return }
            let coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lng)
            if parent.interactionMode == .pin {
                parent.onMapClick(coordinate)
            } else {
                #if os(macOS)
                parent.onContextMenu(coordinate)
                #else
                parent.onMapClick(coordinate)
                #endif
            }
        case "contextmenu":
            guard let lng = body["lng"] as? Double, let lat = body["lat"] as? Double else { return }
            parent.onContextMenu(CLLocationCoordinate2D(latitude: lat, longitude: lng))
        case "moveend":
            guard let lng = body["lng"] as? Double,
                  let lat = body["lat"] as? Double else { return }
            let zoom = body["zoom"] as? Double ?? parent.mapBridge?.currentMapZoom ?? 12.0
            let userInitiated = (body["userInitiated"] as? Bool ?? false) && !shouldSuppressUserMoveEvents
            parent.mapBridge?.mapDidMove(
                center: CLLocationCoordinate2D(latitude: lat, longitude: lng),
                zoom: zoom,
                userInitiated: userInitiated
            )
            parent.onRegionChange(CLLocationCoordinate2D(latitude: lat, longitude: lng))
        default:
            break
        }
    }

    private func syncSimulatedVehicle(to webView: WKWebView) {
        guard let vehicle = parent.simulatedVehicle else {
            return
        }
        pushSimulatedVehicle(vehicle, to: webView)
    }

    private func enqueueVehicleBridgeUpdate(
        _ vehicle: SimulatedVehicleState,
        to webView: WKWebView,
        force: Bool = false
    ) {
        if force {
            vehicleCoalescer.reset()
            dispatchVehicleBridgeUpdate(vehicle, to: webView, force: true) {}
            return
        }
        vehicleCoalescer.enqueue(vehicle) { [weak self] state, completion in
            self?.dispatchVehicleBridgeUpdate(state, to: webView, force: false, completion: completion)
        }
    }

    private func dispatchVehicleBridgeUpdate(
        _ vehicle: SimulatedVehicleState,
        to webView: WKWebView,
        force: Bool,
        completion: @escaping () -> Void
    ) {
        let fingerprint: String
        if vehicle.visible {
            fingerprint = BridgeFrameCoalescer.fingerprint(for: vehicle)
        } else {
            fingerprint = "hidden"
        }

        if !force, fingerprint == lastVehicleFingerprint {
            completion()
            return
        }

        lastVehicleFingerprint = fingerprint
        let signpost = SimulationBridgeInstrumentation.beginBridgeEval()
        let finish: () -> Void = {
            SimulationBridgeInstrumentation.endBridgeEval(signpost)
            completion()
        }

        if vehicle.visible {
            let renderMode = vehicle.renderMode.rawValue
            let footprintJSON = footprintJSONString(from: vehicle.footprintCoordinates)
            let partsJSON = footprintPartsJSONString(from: vehicle.footprintParts)
            let escapedFootprint = escapeJS(footprintJSON)
            let escapedParts = escapeJS(partsJSON)
            webView.evaluateJavaScript(
                "setSimulatedVehicleFootprint(\(vehicle.longitude),\(vehicle.latitude),true,\(vehicle.bearing),'\(escapedFootprint)',\(vehicle.lengthMeters),\(vehicle.widthMeters),'\(renderMode)','\(escapedParts)',\(vehicle.isPassengerCar))"
            ) { _, _ in
                finish()
            }
        } else {
            webView.evaluateJavaScript(
                "setSimulatedVehicleFootprint(0,0,false,0,'[]',12,2.55,'icon')"
            ) { _, _ in
                finish()
            }
        }
    }

    private func footprintJSONString(from coordinates: [CLLocationCoordinate2D]) -> String {
        guard !coordinates.isEmpty else { return "[]" }
        let pairs = coordinates.map { "[\($0.longitude), \($0.latitude)]" }.joined(separator: ",")
        return "[\(pairs)]"
    }

    private func footprintPartsJSONString(from parts: [[CLLocationCoordinate2D]]) -> String {
        guard !parts.isEmpty else { return "[]" }
        let rings = parts.map { ring in
            let pairs = ring.map { "[\($0.longitude), \($0.latitude)]" }.joined(separator: ",")
            return "[\(pairs)]"
        }.joined(separator: ",")
        return "[\(rings)]"
    }

    private func pushSimulatedVehicle(
        _ vehicle: SimulatedVehicleState,
        to webView: WKWebView,
        force: Bool = false
    ) {
        enqueueVehicleBridgeUpdate(vehicle, to: webView, force: force)
    }

    private func routeFingerprint(
        coordinates: [CLLocationCoordinate2D],
        encodedPolyline: String?,
        precision: Int
    ) -> String {
        if let encodedPolyline, !encodedPolyline.isEmpty {
            let digest = SHA256.hash(data: Data(encodedPolyline.utf8))
            let hash = digest.map { String(format: "%02x", $0) }.joined()
            return "enc-\(precision)-\(hash)"
        }

        guard !coordinates.isEmpty else { return "" }

        var payload = Data()
        payload.append(contentsOf: withUnsafeBytes(of: coordinates.count) { Array($0) })
        for coordinate in coordinates {
            payload.append(contentsOf: withUnsafeBytes(of: coordinate.latitude) { Array($0) })
            payload.append(contentsOf: withUnsafeBytes(of: coordinate.longitude) { Array($0) })
        }
        let digest = SHA256.hash(data: payload)
        return "coords-\(coordinates.count)-" + digest.map { String(format: "%02x", $0) }.joined()
    }

    private func escapeJS(_ value: String) -> String {
        value.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'", with: "\\'")
            .replacingOccurrences(of: "\n", with: "\\n")
    }

    private func jsonStringLiteral(_ value: String) -> String {
        if let data = try? JSONEncoder().encode(value),
           let encoded = String(data: data, encoding: .utf8) {
            return encoded
        }
        return "\"\""
    }
}
