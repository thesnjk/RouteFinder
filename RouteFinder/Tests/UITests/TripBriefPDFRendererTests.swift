import Contracts
import Foundation
import Testing
#if canImport(AppKit)
import AppKit
#endif
#if canImport(UIKit)
import UIKit
#endif
@testable import UI

@Test func tripBriefFormatterSectionsIncludeExpectedTitles() {
    let allocation = CompanyBreakAllocation.demoAfternoonBreak()
    let layby = LaybyAdvisory(
        stop: LaybyStop(
            id: "layby-1",
            coordinate: Coordinate(latitude: 52.2, longitude: -0.9),
            label: "M1 J15 Layby"
        ),
        distanceRemainingMeters: 8_000,
        estimatedArrivalSeconds: 2_400,
        confidence: 0.8,
        occupancyPrior: .moderate,
        breakWindowOpensAt: Date(timeIntervalSince1970: 1_700_000_000),
        reasonCodes: [.physicsStress],
        isAdvisory: true
    )
    let report = PredictiveTelemetryReport(
        staticWebETASeconds: 3600,
        kineticPhysicsETASeconds: 4200,
        brakeWearKineticEfficiencyIndex: 72,
        estimatedPremiumSavingsGBP: 0,
        hardDecelEventCount: 0,
        brakeFadeRiskEventCount: 0,
        lateralGViolationCount: 0,
        tireSlipEventCount: 0,
        brakeFadeRiskState: nil,
        events: []
    )
    let context = TripBriefContext(
        predictiveReport: report,
        laybyAdvisory: layby,
        stops: [
            TripBriefStop(label: "Felixstowe Port", role: "origin"),
            TripBriefStop(label: "Manchester Depot", role: "destination"),
        ],
        companyBreaks: [allocation],
        physicsETASeconds: 9_900,
        vehicleLabel: "Artic 1",
        tripStatus: "Rehearsed"
    )

    let sections = TripBriefFormatter.sections(from: context)
    let titles = sections.compactMap(\.title)

    #expect(titles.contains("RouteFinder Trip Brief"))
    #expect(titles.contains("Stops"))
    #expect(titles.contains("Company break windows (planning aid — not legal tacho)"))
    #expect(titles.contains("Predictive telemetry"))
    #expect(titles.contains("Predicted layby (advisory — not legal tacho)"))
}

@Test func tripBriefFormatterPlainTextMatchesSectionsFlattening() {
    let context = TripBriefContext(
        stops: [TripBriefStop(label: "Depot", role: "destination")],
        physicsETASeconds: 3_600,
        vehicleLabel: "Artic 1"
    )
    let fromContext = TripBriefFormatter.plainText(from: context)
    let fromSections = TripBriefFormatter.plainText(from: TripBriefFormatter.sections(from: context))
    #expect(fromContext == fromSections)
}

private func fullTripBriefFixture() -> TripBriefContext {
    let layby = LaybyAdvisory(
        stop: LaybyStop(
            id: "layby-1",
            coordinate: Coordinate(latitude: 52.2, longitude: -0.9),
            label: "M1 J15 Layby"
        ),
        distanceRemainingMeters: 8_000,
        estimatedArrivalSeconds: 2_400,
        confidence: 0.8,
        occupancyPrior: .moderate,
        breakWindowOpensAt: Date(timeIntervalSince1970: 1_700_000_000),
        reasonCodes: [.physicsStress],
        isAdvisory: true
    )
    let report = PredictiveTelemetryReport(
        staticWebETASeconds: 3600,
        kineticPhysicsETASeconds: 4200,
        brakeWearKineticEfficiencyIndex: 72,
        estimatedPremiumSavingsGBP: 150,
        hardDecelEventCount: 2,
        brakeFadeRiskEventCount: 1,
        lateralGViolationCount: 0,
        tireSlipEventCount: 1,
        brakeFadeRiskState: .elevated,
        events: []
    )
    return TripBriefContext(
        predictiveReport: report,
        laybyAdvisory: layby,
        stops: [
            TripBriefStop(label: "Felixstowe Port", role: "origin"),
            TripBriefStop(label: "Manchester Depot", role: "destination"),
        ],
        companyBreaks: [CompanyBreakAllocation.demoAfternoonBreak()],
        physicsETASeconds: 9_900,
        vehicleLabel: "Artic 1",
        tripStatus: "Rehearsed"
    )
}

@Test func tripBriefPDFRendererProducesValidPDFHeader() {
    let data = TripBriefPDFRenderer.pdfData(from: fullTripBriefFixture())
    #expect(!data.isEmpty)
    let prefix = String(decoding: data.prefix(4), as: UTF8.self)
    #expect(prefix == "%PDF")
}

@Test func tripBriefPDFRendererProducesNonTrivialPayload() {
    let data = TripBriefPDFRenderer.pdfData(from: fullTripBriefFixture())
    #expect(data.count > 512)
}

@Test func tripBriefPDFRendererWithMapImageIsLargerThanTextOnly() throws {
    let context = fullTripBriefFixture()
    let textOnly = TripBriefPDFRenderer.pdfData(from: context)
    let mapPNG = try #require(minimalPNGData())
    let withMap = TripBriefPDFRenderer.pdfData(from: context, mapImagePNG: mapPNG)
    #expect(withMap.count > textOnly.count)
    let prefix = String(decoding: withMap.prefix(4), as: UTF8.self)
    #expect(prefix == "%PDF")
}

@Test func tripBriefPDFRendererWithoutMapOmitsMapBlock() {
    let context = fullTripBriefFixture()
    let textOnly = TripBriefPDFRenderer.pdfData(from: context)
    let withoutMap = TripBriefPDFRenderer.pdfData(from: context, mapImagePNG: nil)
    #expect(withoutMap.count == textOnly.count)
    let prefix = String(decoding: withoutMap.prefix(4), as: UTF8.self)
    #expect(prefix == "%PDF")
}

#if os(macOS) || os(iOS)
@Test func routeMapSnapshotRendererReturnsPNGForUKRoute() async {
    let coordinates = [
        Coordinate(latitude: 52.2053, longitude: 0.1218),
        Coordinate(latitude: 52.4862, longitude: -1.8904),
    ]
    let png = await RouteMapSnapshotRenderer.snapshot(routeCoordinates: coordinates)
    #expect(png != nil)
    #expect((png?.count ?? 0) > 100)
}
#endif

private func minimalPNGData() -> Data? {
    #if canImport(UIKit)
    let renderer = UIGraphicsImageRenderer(size: CGSize(width: 10, height: 10))
    let image = renderer.image { context in
        UIColor.systemBlue.setFill()
        context.fill(CGRect(x: 0, y: 0, width: 10, height: 10))
    }
    return image.pngData()
    #elseif canImport(AppKit)
    let image = NSImage(size: NSSize(width: 10, height: 10))
    image.lockFocus()
    NSColor.systemBlue.setFill()
    NSRect(x: 0, y: 0, width: 10, height: 10).fill()
    image.unlockFocus()
    guard let tiff = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiff) else {
        return nil
    }
    return bitmap.representation(using: .png, properties: [:])
    #else
    return nil
    #endif
}
