import SwiftUI

#if os(iOS)
import UIKit
#endif

/// Clears search-field focus and dismisses the keyboard when applicable.
@MainActor
func dismissRouteSearchFocus(_ focusedWaypointID: FocusState<UUID?>.Binding) {
    focusedWaypointID.wrappedValue = nil
    #if os(iOS)
    UIApplication.shared.sendAction(
        #selector(UIResponder.resignFirstResponder),
        to: nil,
        from: nil,
        for: nil
    )
    #endif
}

#if os(iOS)
/// Resigns the keyboard without a focus binding.
@MainActor
func dismissKeyboard() {
    UIApplication.shared.sendAction(
        #selector(UIResponder.resignFirstResponder),
        to: nil,
        from: nil,
        for: nil
    )
}
#endif
