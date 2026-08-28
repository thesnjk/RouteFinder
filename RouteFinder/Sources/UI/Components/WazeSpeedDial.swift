import SwiftUI

/// Circular Waze-style speed dial showing current speed and posted limit.
public struct WazeSpeedDial: View {
    /// Current vehicle speed in the active display unit.
    public let currentSpeed: Double
    /// Posted speed limit in the same unit, when known.
    public let speedLimit: Double?
    /// Traffic-adjusted effective limit when lower than the posted limit.
    public let effectiveSpeedLimit: Double?
    /// Unit label such as `"mph"` or `"km/h"`.
    public let unitLabel: String
    /// Compact HUD sizing when embedded in the collapsed summary bar.
    public let compact: Bool

    /// Creates a speed dial.
    public init(
        currentSpeed: Double,
        speedLimit: Double?,
        effectiveSpeedLimit: Double? = nil,
        unitLabel: String,
        compact: Bool = false
    ) {
        self.currentSpeed = currentSpeed
        self.speedLimit = speedLimit
        self.effectiveSpeedLimit = effectiveSpeedLimit
        self.unitLabel = unitLabel
        self.compact = compact
    }

    private var dialSize: CGFloat { compact ? 56 : 88 }
    private var speedFont: Font {
        compact ? .system(size: 18, weight: .bold, design: .rounded)
            : .system(size: 28, weight: .bold, design: .rounded)
    }

    private var displayedLimit: Double? {
        if let effectiveSpeedLimit, let speedLimit, effectiveSpeedLimit + 0.5 < speedLimit {
            return effectiveSpeedLimit
        }
        return speedLimit
    }

    private var showsCongestion: Bool {
        guard let effectiveSpeedLimit, let speedLimit else { return false }
        return effectiveSpeedLimit + 0.5 < speedLimit
    }

    private var isOverLimit: Bool {
        guard let displayedLimit else { return false }
        return currentSpeed > displayedLimit + 0.5
    }

    public var body: some View {
        ZStack {
            Circle()
                .fill(.ultraThinMaterial)
            Circle()
                .strokeBorder(ringColor.opacity(0.85), lineWidth: compact ? 3 : 4)

            VStack(spacing: compact ? 0 : 2) {
                if showsCongestion {
                    Image(systemName: "car.2.fill")
                        .font(.system(size: compact ? 8 : 10, weight: .bold))
                        .foregroundStyle(.orange)
                }
                Text("\(Int(round(currentSpeed)))")
                    .font(speedFont)
                    .monospacedDigit()
                    .foregroundStyle(isOverLimit ? RFColor.hazard : .primary)
                if let speedLimit {
                    if showsCongestion, let effectiveSpeedLimit {
                        HStack(spacing: 2) {
                            Text("\(Int(round(speedLimit)))")
                                .font(.system(size: compact ? 7 : 8, weight: .medium))
                                .foregroundStyle(.tertiary)
                                .strikethrough()
                            Text("\(Int(round(effectiveSpeedLimit)))")
                                .font(compact ? .caption2.weight(.semibold) : .caption.weight(.semibold))
                                .foregroundStyle(.orange)
                                .monospacedDigit()
                        }
                    } else {
                        Text("\(Int(round(speedLimit)))")
                            .font(compact ? .caption2.weight(.semibold) : .caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
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
        if showsCongestion { return .orange }
        return isOverLimit ? RFColor.hazard : Color.primary.opacity(0.35)
    }

    private var accessibilityLabel: String {
        if let displayedLimit {
            return "\(Int(round(currentSpeed))) \(unitLabel), limit \(Int(round(displayedLimit)))"
        }
        return "\(Int(round(currentSpeed))) \(unitLabel)"
    }
}
