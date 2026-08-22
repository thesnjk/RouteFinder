import Contracts
import SwiftUI

/// Route metrics and error display.
public struct ResultsPanel: View {
    let result: SearchResult?
    let errorMessage: String?
    let hurryModeActive: Bool

    public init(result: SearchResult?, errorMessage: String?, hurryModeActive: Bool = false) {
        self.result = result
        self.errorMessage = errorMessage
        self.hurryModeActive = hurryModeActive
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Results")
                .font(.headline)
                .vibrancyLabel()

            if hurryModeActive {
                Label("Hurry Mode Active", systemImage: "bolt.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }

            if let errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
                    .font(.callout)
            } else if let result {
                Text(result.explanation)
                    .font(.callout)
                    .vibrancyLabel()

                HStack {
                    Label(String(format: "%.1f km", result.metrics.totalDistance / 1000), systemImage: "ruler")
                    Label(formatTime(result.metrics.totalTime), systemImage: "clock")
                }
                .font(.caption)

                HStack {
                    Label("\(result.nodesVisited) nodes", systemImage: "point.3.connected.trianglepath.dotted")
                    Label(String(format: "%.0f ms", result.runtime * 1000), systemImage: "speedometer")
                }
                .font(.caption)

                if result.metrics.speedCameraCount > 0 {
                    Label("\(result.metrics.speedCameraCount) speed camera(s)", systemImage: "camera.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }

                HStack(spacing: 12) {
                    if result.metrics.tollSegmentCount > 0 {
                        Label("\(result.metrics.tollSegmentCount) toll(s)", systemImage: "dollarsign.circle")
                            .font(.caption2)
                    }
                    if result.metrics.ferrySegmentCount > 0 {
                        Label("\(result.metrics.ferrySegmentCount) ferry(s)", systemImage: "ferry")
                            .font(.caption2)
                    }
                    if result.metrics.tunnelSegmentCount > 0 {
                        Label("\(result.metrics.tunnelSegmentCount) tunnel(s)", systemImage: "tunnel")
                            .font(.caption2)
                    }
                }
            } else {
                Text("Enter locations and tap Find Route.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func formatTime(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds) / 60
        if minutes < 60 { return "\(minutes) min" }
        return "\(minutes / 60)h \(minutes % 60)m"
    }
}
