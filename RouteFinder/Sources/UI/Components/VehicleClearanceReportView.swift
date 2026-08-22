import Contracts
import SwiftUI

/// Verification summary for HGV dimensional clearance on the active route.
public struct VehicleClearanceReportView: View {
  let vehicle: VehicleProfile
  let isHGVMode: Bool
  let routeSucceeded: Bool
  let isDimensionBlocked: Bool

  private let maxHeightMeters = 4.0
  private let maxWeightTonnes = 44.0

  /// Creates a clearance report for the current vehicle and route state.
  public init(
    vehicle: VehicleProfile,
    isHGVMode: Bool,
    routeSucceeded: Bool,
    isDimensionBlocked: Bool
  ) {
    self.vehicle = vehicle
    self.isHGVMode = isHGVMode
    self.routeSucceeded = routeSucceeded
    self.isDimensionBlocked = isDimensionBlocked
  }

  public var body: some View {
    VStack(alignment: .leading, spacing: RFSpacing.sm) {
      HStack {
        Text("Vehicle Safety Clearance")
          .font(RFFont.sectionTitle)
        Spacer()
        statusBadge
      }

      LazyVGrid(
        columns: [GridItem(.flexible()), GridItem(.flexible())],
        spacing: RFSpacing.sm
      ) {
        clearanceCell(
          title: "Height",
          value: formattedDimension(vehicle.height, unit: "m"),
          limit: "≤ \(String(format: "%.1f", maxHeightMeters)) m",
          passed: heightPassed
        )
        clearanceCell(
          title: "Weight",
          value: formattedDimension(vehicle.weight, unit: "t"),
          limit: "≤ \(String(format: "%.0f", maxWeightTonnes)) t",
          passed: weightPassed
        )
        clearanceCell(
          title: "Bridge Corridor",
          value: bridgeCorridorValue,
          limit: "ORS HGV restrictions",
          passed: bridgeCorridorPassed
        )
        clearanceCell(
          title: "Profile",
          value: vehicle.savedProfileName ?? "Custom",
          limit: isHGVMode ? "HGV mode" : "Standard",
          passed: isHGVMode
        )
      }
    }
    .padding(RFSpacing.sm)
    .controlSheetStyle()
  }

  private var statusBadge: some View {
    let verified = routeSucceeded && !isDimensionBlocked && isHGVMode
    return Text(verified ? "Verified" : "Review")
      .font(RFFont.caption.weight(.semibold))
      .padding(.horizontal, 10)
      .padding(.vertical, 4)
      .background(
        (verified ? Color.green : Color.orange).opacity(0.2),
        in: Capsule()
      )
      .foregroundStyle(verified ? .green : .orange)
  }

  private var heightPassed: Bool {
    guard let height = vehicle.height else { return isHGVMode }
    return height <= maxHeightMeters
  }

  private var weightPassed: Bool {
    guard let weight = vehicle.weight else { return isHGVMode }
    return weight <= maxWeightTonnes
  }

  private var bridgeCorridorPassed: Bool {
    routeSucceeded && !isDimensionBlocked
  }

  private var bridgeCorridorValue: String {
    if isDimensionBlocked { return "Blocked" }
    if routeSucceeded { return "Clear" }
    return "Pending"
  }

  private func formattedDimension(_ value: Double?, unit: String) -> String {
    guard let value else { return "Default" }
    return String(format: "%.1f %@", value, unit)
  }

  private func clearanceCell(
    title: String,
    value: String,
    limit: String,
    passed: Bool
  ) -> some View {
    VStack(alignment: .leading, spacing: 4) {
      HStack(spacing: 4) {
        Image(systemName: passed ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
          .font(.caption)
          .foregroundStyle(passed ? .green : .orange)
        Text(title)
          .font(RFFont.caption.weight(.semibold))
      }
      Text(value)
        .font(RFFont.summary)
      Text(limit)
        .font(.caption2)
        .foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(RFSpacing.sm)
    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
  }
}
