import SwiftUI

/// Circular Waze-style speed dial showing current speed and posted limit.
public struct WazeSpeedDial: View {
    /// Current vehicle speed in the active display unit.
    public let currentSpeed: Double
    /// Posted speed limit in the same unit, when known.
    public let speedLimit: Double?
    /// Unit label such as `"mph"` or `"km/h"`.
    public let unitLabel: String
    /// Compact HUD sizing when embedded in the collapsed summary bar.
    public let compact: Bool

    /// Creates a speed dial.
    public init(
        currentSpeed: Double,
        speedLimit: Double?,
        unitLabel: String,
        compact: Bool = false
    ) {
        self.currentSpeed = currentSpeed
        self.speedLimit = speedLimit
        self.unitLabel = unitLabel
        self.compact = compact
    }

    private var dialSize: CGFloat { compact ? 56 : 88 }
    private var speedFont: Font {
        compact ? .system(size: 18, weight: .bold, design: .rounded)
            : .system(size: 28, weight: .bold, design: .rounded)
    }

    private var isOverLimit: Bool {
        guard let speedLimit else { return false }
        return currentSpeed > speedLimit + 0.5
    }

    public var body: some View {
        ZStack {
            Circle()
                .fill(.ultraThinMaterial)
            Circle()
                .strokeBorder(ringColor.opacity(0.85), lineWidth: compact ? 3 : 4)

            VStack(spacing: compact ? 0 : 2) {
                Text("\(Int(round(currentSpeed)))")
                    .font(speedFont)
                    .monospacedDigit()
                    .foregroundStyle(isOverLimit ? RFColor.hazard : .primary)
                if let speedLimit {
                    Text("\(Int(round(speedLimit)))")
                        .font(compact ? .caption2.weight(.semibold) : .caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                Text(unitLabel)
                    .font(.system(size: compact ? 8 : 10, weight: .medium))
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(width: dialSize, height: dialSize)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }

    private var ringColor: Color {
        isOverLimit ? RFColor.hazard : Color.primary.opacity(0.35)
    }

    private var accessibilityLabel: String {
        if let speedLimit {
            return "\(Int(round(currentSpeed))) \(unitLabel), limit \(Int(round(speedLimit)))"
        }
        return "\(Int(round(currentSpeed))) \(unitLabel)"
    }
}
