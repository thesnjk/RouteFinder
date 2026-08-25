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
  private let maxLengthMeters = 18.75
  private let maxAxleTonnes = 11.5

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
          title: "Length",
          value: formattedDimension(vehicle.length, unit: "m"),
          limit: "≤ \(String(format: "%.2f", maxLengthMeters)) m",
          passed: lengthPassed
        )
        clearanceCell(
          title: "Axle",
          value: formattedDimension(vehicle.axleWeight, unit: "t"),
          limit: "≤ \(String(format: "%.1f", maxAxleTonnes)) t",
          passed: axlePassed
        )
        clearanceCell(
          title: "Hazmat / ADR",
          value: hazmatValue,
          limit: "ORS HGV restrictions",
          passed: hazmatPassed
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

  private var lengthPassed: Bool {
    guard let length = vehicle.length else { return isHGVMode }
    return length <= maxLengthMeters
  }

  private var axlePassed: Bool {
    guard let axle = vehicle.axleWeight else { return isHGVMode }
    return axle <= maxAxleTonnes
  }

  private var hazmatPassed: Bool {
    !isDimensionBlocked
  }

  private var hazmatValue: String {
    let hazmat = vehicle.hazmatClass.map { $0.rawValue } ?? "None"
    let tunnel = vehicle.tunnelRestrictionCode.map { $0.rawValue.uppercased() } ?? "-"
    return "\(hazmat) / \(tunnel)"
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
    guard let value else { return "—" }
    return String(format: "%.2f %@", value, unit)
  }

  private func clearanceCell(
    title: String,
    value: String,
    limit: String,
    passed: Bool
  ) -> some View {
    VStack(alignment: .leading, spacing: 2) {
      Text(title)
        .font(RFFont.caption)
        .foregroundStyle(.secondary)
      Text(value)
        .font(RFFont.body.weight(.semibold))
        .foregroundStyle(passed ? Color.primary : Color.orange)
      Text(limit)
        .font(.caption2)
        .foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(8)
    .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
  }
}
