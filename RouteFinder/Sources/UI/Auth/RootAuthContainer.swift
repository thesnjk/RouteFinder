import MapLibreUI
import SwiftUI

/// Root container: auth gate until unlocked, then the main map UI.
public struct RootAuthContainer: View {
    @State private var session = SessionController()

    public init() {}

    public var body: some View {
        Group {
            switch session.phase {
            case .loading, .unauthenticated:
                AuthGateView(session: session)
            case .authenticated:
                ContentView(session: session)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(MapCanvasBackdrop.color)
        .ignoresSafeArea()
    }
}
