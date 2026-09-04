import CoreImage
import CoreImage.CIFilterBuiltins
import SwiftUI
#if os(macOS)
import AppKit
#else
import UIKit
#endif

/// Generates a scannable QR image encoding a fleet vehicle UUID for driver pairing.
public enum VehiclePairingQRCode {
    /// Payload prefix so scanners can reject unrelated QR codes.
    public static let payloadPrefix = "routefinder-vehicle:"

    /// Builds the canonical pairing payload string for a vehicle UUID.
    public static func payload(for vehicleId: UUID) -> String {
        "\(payloadPrefix)\(vehicleId.uuidString)"
    }

    /// Parses a vehicle UUID from a scanned QR payload or a raw UUID string.
    public static func parseVehicleId(from raw: String) -> UUID? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.lowercased().hasPrefix(payloadPrefix) {
            let uuidPart = String(trimmed.dropFirst(payloadPrefix.count))
            return UUID(uuidString: uuidPart)
        }
        return UUID(uuidString: trimmed)
    }

    /// Renders a QR code image for the given vehicle UUID.
    @MainActor
    public static func image(for vehicleId: UUID, dimension: CGFloat = 200) -> Image? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(payload(for: vehicleId).utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage else { return nil }

        let scale = dimension / output.extent.width
        let scaled = output.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        let context = CIContext()
        guard let cgImage = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        #if os(macOS)
        let nsImage = NSImage(cgImage: cgImage, size: NSSize(width: dimension, height: dimension))
        return Image(nsImage: nsImage)
        #else
        return Image(uiImage: UIImage(cgImage: cgImage))
        #endif
    }
}

/// SwiftUI view showing a vehicle pairing QR code plus copyable UUID.
public struct VehiclePairingQRView: View {
    public let vehicleId: UUID
    public let vehicleLabel: String
    @State private var copied = false

    public init(vehicleId: UUID, vehicleLabel: String) {
        self.vehicleId = vehicleId
        self.vehicleLabel = vehicleLabel
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: RFSpacing.sm) {
            Text("Driver pairing")
                .font(RFFont.sectionTitle)
            Text("Show this QR to the driver, or copy the UUID into Settings → Fleet setup wizard.")
                .font(RFFont.caption)
                .foregroundStyle(.secondary)
            Text(vehicleLabel)
                .font(RFFont.caption.weight(.semibold))

            if let qr = VehiclePairingQRCode.image(for: vehicleId, dimension: 180) {
                qr
                    .interpolation(.none)
                    .resizable()
                    .frame(width: 180, height: 180)
                    .accessibilityLabel("Vehicle pairing QR code")
            }

            Text(vehicleId.uuidString)
                .font(.system(.caption2, design: .monospaced))
                .textSelection(.enabled)

            Button(copied ? "Copied" : "Copy UUID") {
                #if os(macOS)
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(vehicleId.uuidString, forType: .string)
                #else
                UIPasteboard.general.string = vehicleId.uuidString
                #endif
                copied = true
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .glassPanel(cornerRadius: 14)
        .padding(RFSpacing.sm)
    }
}
