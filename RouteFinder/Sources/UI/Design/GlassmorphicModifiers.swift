import SwiftUI

/// Frosted glass panel with rounded corners and subtle border.
public struct GlassPanel: ViewModifier {
    private let cornerRadius: CGFloat

    public init(cornerRadius: CGFloat = 16) {
        self.cornerRadius = cornerRadius
    }

    public func body(content: Content) -> some View {
        content
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .strokeBorder(.white.opacity(0.2), lineWidth: 0.5)
            )
    }
}

/// Sidebar-scale control sheet glass styling.
public struct ControlSheetStyle: ViewModifier {
    public init() {}

    public func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: 16)
                    .fill(.regularMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(.white.opacity(0.05))
                    )
            }
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(.white.opacity(0.2), lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.12), radius: 20, y: 8)
            .shadow(color: .black.opacity(0.06), radius: 4, y: 2)
    }
}

/// Frosted button with spring press animation.
public struct GlassButton: ViewModifier {
    @State private var isPressed = false

    public init() {}

    public func body(content: Content) -> some View {
        content
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(.regularMaterial, in: Capsule())
            .scaleEffect(isPressed ? 0.96 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isPressed)
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in isPressed = true }
                    .onEnded { _ in isPressed = false }
            )
    }
}

/// Section header styling for control sheet sections.
public struct SectionHeaderStyle: ViewModifier {
    public init() {}

    public func body(content: Content) -> some View {
        content
            .font(RFFont.sectionTitle)
            .foregroundStyle(.primary)
    }
}

/// Vibrancy-enhanced label styling for text on glass surfaces.
public struct VibrancyLabel: ViewModifier {
    public init() {}

    public func body(content: Content) -> some View {
        content
            .foregroundStyle(.primary)
            .shadow(color: .black.opacity(0.1), radius: 1, y: 1)
    }
}

/// Multi-layer shadow for 3D lift effect on glass panels.
public struct DepthShadow: ViewModifier {
    public init() {}

    public func body(content: Content) -> some View {
        content
            .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
            .shadow(color: .black.opacity(0.04), radius: 12, y: 6)
    }
}

/// Inset glass text field styling.
public struct GlassTextFieldStyle: TextFieldStyle {
    public func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(.white.opacity(0.15), lineWidth: 0.5)
            )
    }
}

/// Orange pill badge for active Hurry Mode.
public struct HurryModeBadge: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse = false

    public init() {}

    public var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "camera.fill")
            Text("Speed Camera Evasion Active")
                .font(.caption.weight(.semibold))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(RFColor.hazard.gradient, in: Capsule())
        .scaleEffect(reduceMotion || !pulse ? 1.0 : 1.02)
        .animation(reduceMotion ? nil : .easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: pulse)
        .onAppear {
            guard !reduceMotion else { return }
            pulse = true
        }
    }
}

extension View {
    public func glassPanel(cornerRadius: CGFloat = 16) -> some View {
        modifier(GlassPanel(cornerRadius: cornerRadius))
    }

    public func controlSheetStyle() -> some View {
        modifier(ControlSheetStyle())
    }

    public func glassButton() -> some View {
        modifier(GlassButton())
    }

    public func sectionHeader() -> some View {
        modifier(SectionHeaderStyle())
    }

    public func vibrancyLabel() -> some View {
        modifier(VibrancyLabel())
    }

    public func depthShadow() -> some View {
        modifier(DepthShadow())
    }
}
