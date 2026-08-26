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

/// Renders a shareable trip brief as a multi-page PDF document.
public enum TripBriefPDFRenderer {
    private static let pageWidth: CGFloat = 612
    private static let pageHeight: CGFloat = 792
    private static let margin: CGFloat = 48
    private static let lineSpacing: CGFloat = 4
    private static let sectionSpacing: CGFloat = 14

    /// Builds PDF data for the given trip brief context.
    public static func pdfData(from context: TripBriefContext) -> Data {
        let sections = TripBriefFormatter.sections(from: context)
        guard !sections.isEmpty else { return Data() }

        let data = NSMutableData()
        guard let consumer = CGDataConsumer(data: data as CFMutableData) else { return Data() }

        var mediaBox = CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight)
        guard let pdfContext = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else {
            return Data()
        }

        let contentWidth = pageWidth - (margin * 2)
        var renderer = PageRenderer(context: pdfContext, yTop: margin)

        pdfContext.beginPDFPage(nil)

        let timestamp = Date.now.formatted(date: .abbreviated, time: .shortened)
        renderer.draw(
            text: "RouteFinder Trip Brief",
            font: titleFont(),
            width: contentWidth,
            x: margin,
            minimumHeight: 22
        )
        renderer.draw(
            text: "Generated \(timestamp)",
            font: captionFont(),
            width: contentWidth,
            x: margin,
            minimumHeight: 16
        )
        renderer.advance(by: sectionSpacing)

        for (index, section) in sections.enumerated() {
            if index == 0 {
                for line in section.lines {
                    renderer.draw(
                        text: line,
                        font: bodyFont(),
                        width: contentWidth,
                        x: margin,
                        minimumHeight: 14
                    )
                }
                continue
            }

            if index == sections.count - 1 {
                renderer.advance(by: sectionSpacing)
                for line in section.lines {
                    renderer.draw(
                        text: line,
                        font: captionFont(),
                        width: contentWidth,
                        x: margin,
                        minimumHeight: 14
                    )
                }
                continue
            }

            guard section.title != nil || !section.lines.isEmpty else { continue }

            renderer.advance(by: sectionSpacing)
            if let title = section.title {
                renderer.draw(
                    text: title,
                    font: sectionTitleFont(),
                    width: contentWidth,
                    x: margin,
                    minimumHeight: 16
                )
                renderer.advance(by: 4)
            }
            for line in section.lines {
                renderer.draw(
                    text: line,
                    font: bodyFont(),
                    width: contentWidth,
                    x: margin,
                    minimumHeight: 14
                )
            }
        }

        pdfContext.endPDFPage()
        pdfContext.closePDF()
        return data as Data
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
            options: [.usesLineFragmentOrigin, .usesFontLeading]
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
        context.saveGState()
        CTFrameDraw(frame, context)
        context.restoreGState()
    }

    private static func attributedString(text: String, font: PlatformFont) -> NSAttributedString {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineBreakMode = .byWordWrapping
        return NSAttributedString(
            string: text,
            attributes: [
                .font: font,
                .paragraphStyle: paragraphStyle,
            ]
        )
    }

    private static func titleFont() -> PlatformFont {
        #if canImport(UIKit)
        return UIFont.boldSystemFont(ofSize: 18)
        #else
        return NSFont.boldSystemFont(ofSize: 18)
        #endif
    }

    private static func sectionTitleFont() -> PlatformFont {
        #if canImport(UIKit)
        return UIFont.systemFont(ofSize: 13, weight: .semibold)
        #else
        return NSFont.systemFont(ofSize: 13, weight: .semibold)
        #endif
    }

    private static func bodyFont() -> PlatformFont {
        #if canImport(UIKit)
        return UIFont.systemFont(ofSize: 11)
        #else
        return NSFont.systemFont(ofSize: 11)
        #endif
    }

    private static func captionFont() -> PlatformFont {
        #if canImport(UIKit)
        return UIFont.systemFont(ofSize: 10)
        #else
        return NSFont.systemFont(ofSize: 10)
        #endif
    }
}
