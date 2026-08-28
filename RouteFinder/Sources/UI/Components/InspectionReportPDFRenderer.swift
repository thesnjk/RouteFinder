import Contracts
import CoreGraphics
import CoreText
import Foundation

#if canImport(UIKit)
import UIKit
private typealias PlatformFont = UIFont
#elseif canImport(AppKit)
import AppKit
private typealias PlatformFont = NSFont
#endif

/// Renders a completed DVSA-style walkaround inspection as a PDF report.
public enum InspectionReportPDFRenderer {
    private static let pageWidth: CGFloat = 612
    private static let pageHeight: CGFloat = 792
    private static let margin: CGFloat = 48
    private static let lineSpacing: CGFloat = 4
    private static let sectionSpacing: CGFloat = 12

    /// Builds PDF data for the given inspection record.
    public static func pdfData(from record: InspectionRecord) -> Data {
        let data = NSMutableData()
        guard let consumer = CGDataConsumer(data: data as CFMutableData) else { return Data() }

        var mediaBox = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
        guard let pdfContext = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else {
            return Data()
        }

        let contentWidth = pageWidth - (margin * 2)
        var renderer = PageRenderer(context: pdfContext, yTop: margin)

        pdfContext.beginPDFPage(nil)

        renderer.draw(text: "RouteFinder Walkaround Report", font: titleFont(), width: contentWidth, x: margin, minimumHeight: 22)
        renderer.draw(text: record.vehicleLabel, font: sectionTitleFont(), width: contentWidth, x: margin, minimumHeight: 16)
        if let plate = record.registrationPlate {
            renderer.draw(text: "Registration: \(plate)", font: bodyFont(), width: contentWidth, x: margin, minimumHeight: 14)
        }
        renderer.draw(
            text: "Started: \(formatted(record.createdAt))",
            font: bodyFont(),
            width: contentWidth,
            x: margin,
            minimumHeight: 14
        )
        if let completedAt = record.completedAt {
            renderer.draw(
                text: "Completed: \(formatted(completedAt))",
                font: bodyFont(),
                width: contentWidth,
                x: margin,
                minimumHeight: 14
            )
        }
        renderer.draw(
            text: "Summary: \(record.items.count) checks · \(record.defectCount) defect(s) · \(Int(record.completionFraction * 100))% complete",
            font: bodyFont(),
            width: contentWidth,
            x: margin,
            minimumHeight: 14
        )
        renderer.advance(by: sectionSpacing)
        renderer.draw(
            text: "This report is a local planning aid. Official defect books and operator procedures remain authoritative.",
            font: captionFont(),
            width: contentWidth,
            x: margin,
            minimumHeight: 14
        )
        renderer.advance(by: sectionSpacing)

        for group in record.itemsGroupedByZone() {
            renderer.draw(
                text: group.zone.displayTitle,
                font: sectionTitleFont(),
                width: contentWidth,
                x: margin,
                minimumHeight: 16
            )
            renderer.advance(by: 4)
            for item in group.items {
                var line = "• \(item.label) — \(statusLabel(item.status))"
                if item.status == .defect, let note = item.note?.trimmingCharacters(in: .whitespacesAndNewlines), !note.isEmpty {
                    line += " (\(note))"
                }
                renderer.draw(text: line, font: bodyFont(), width: contentWidth, x: margin, minimumHeight: 14)
            }
            renderer.advance(by: sectionSpacing)
        }

        pdfContext.endPDFPage()
        pdfContext.closePDF()
        return data as Data
    }

    private static func statusLabel(_ status: InspectionItemStatus) -> String {
        switch status {
        case .notChecked: return "Not checked"
        case .pass: return "Pass"
        case .defect: return "Defect"
        case .notApplicable: return "N/A"
        }
    }

    private static func formatted(_ date: Date) -> String {
        date.formatted(date: .abbreviated, time: .shortened)
    }

    private struct PageRenderer {
        let context: CGContext
        var yTop: CGFloat

        mutating func advance(by amount: CGFloat) {
            yTop += amount
            ensureSpace(for: 0)
        }

        mutating func draw(
            text: String,
            font: PlatformFont,
            width: CGFloat,
            x: CGFloat,
            minimumHeight: CGFloat
        ) {
            let height = max(measuredHeight(for: text, font: font, width: width), minimumHeight)
            ensureSpace(for: height)
            drawText(text, font: font, x: x, yTop: yTop, width: width, height: height, context: context)
            yTop += height + lineSpacing
        }

        mutating func ensureSpace(for height: CGFloat) {
            let bottomLimit = pageHeight - margin
            guard yTop + height > bottomLimit else { return }
            context.endPDFPage()
            context.beginPDFPage(nil)
            yTop = margin
        }
    }

    private static func measuredHeight(for text: String, font: PlatformFont, width: CGFloat) -> CGFloat {
        let attributed = attributedString(text: text, font: font)
        let rect = attributed.boundingRect(
            with: CGSize(width: width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            context: nil
        )
        return ceil(rect.height)
    }

    private static func drawText(
        _ text: String,
        font: PlatformFont,
        x: CGFloat,
        yTop: CGFloat,
        width: CGFloat,
        height: CGFloat,
        context: CGContext
    ) {
        let attributed = attributedString(text: text, font: font)
        let drawRect = CGRect(x: x, y: pageHeight - yTop - height, width: width, height: height)
        let framesetter = CTFramesetterCreateWithAttributedString(attributed)
        let path = CGPath(rect: drawRect, transform: nil)
        let frame = CTFramesetterCreateFrame(
            framesetter,
            CFRange(location: 0, length: attributed.length),
            path,
            nil
        )
        context.textMatrix = .identity
        CTFrameDraw(frame, context)
    }

    private static func attributedString(text: String, font: PlatformFont) -> NSAttributedString {
        NSAttributedString(string: text, attributes: [.font: font])
    }

    private static func titleFont() -> PlatformFont {
        #if canImport(UIKit)
        return PlatformFont.boldSystemFont(ofSize: 20)
        #else
        return PlatformFont.boldSystemFont(ofSize: 20)
        #endif
    }

    private static func sectionTitleFont() -> PlatformFont {
        #if canImport(UIKit)
        return PlatformFont.boldSystemFont(ofSize: 14)
        #else
        return PlatformFont.boldSystemFont(ofSize: 14)
        #endif
    }

    private static func bodyFont() -> PlatformFont {
        #if canImport(UIKit)
        return PlatformFont.systemFont(ofSize: 11)
        #else
        return PlatformFont.systemFont(ofSize: 11)
        #endif
    }

    private static func captionFont() -> PlatformFont {
        #if canImport(UIKit)
        return PlatformFont.systemFont(ofSize: 9)
        #else
        return PlatformFont.systemFont(ofSize: 9)
        #endif
    }
}
