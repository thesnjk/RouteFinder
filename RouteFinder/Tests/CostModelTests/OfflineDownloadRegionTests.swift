import Contracts
import Testing

struct OfflineDownloadRegionTests {
    @Test func eastAngliaMetadataIsPresent() {
        let region = OfflineDownloadRegion.eastAnglia
        #expect(region.id == "eastAnglia")
        #expect(region.displayName.contains("East Anglia"))
        #expect(region.displayName.contains("A14"))
        #expect(!region.sizeWarning.isEmpty)
        #expect(region.sizeWarning.localizedCaseInsensitiveContains("medium"))
    }

    @Test func midlandsMetadataIsPresent() {
        let region = OfflineDownloadRegion.midlands
        #expect(region.id == "midlands")
        #expect(region.displayName.contains("Midlands"))
        #expect(region.displayName.contains("M1"))
        #expect(!region.sizeWarning.isEmpty)
        #expect(region.sizeWarning.localizedCaseInsensitiveContains("medium"))
    }

    @Test func northWestMetadataIsPresent() {
        let region = OfflineDownloadRegion.northWest
        #expect(region.id == "northWest")
        #expect(region.displayName.contains("North West"))
        #expect(region.displayName.contains("M6"))
        #expect(!region.sizeWarning.isEmpty)
        #expect(region.sizeWarning.localizedCaseInsensitiveContains("medium"))
    }

    @Test func eastAngliaContainsNorfolkDemoCenter() {
        let norfolk = OfflineDownloadRegion.demoNorfolk.boundingBox
        let centerLat = (norfolk.minLat + norfolk.maxLat) / 2
        let centerLon = (norfolk.minLon + norfolk.maxLon) / 2
        let east = OfflineDownloadRegion.eastAnglia.boundingBox
        #expect(east.minLat <= centerLat && centerLat <= east.maxLat)
        #expect(east.minLon <= centerLon && centerLon <= east.maxLon)
        #expect(OfflineDownloadRegion.eastAnglia.contains(.demoNorfolk))
    }

    @Test func midlandsDoesNotContainEastAnglia() {
        #expect(!OfflineDownloadRegion.midlands.contains(.eastAnglia))
        #expect(!OfflineDownloadRegion.eastAnglia.contains(.midlands))
    }

    @Test func northWestDoesNotContainMidlandsOrEastAnglia() {
        #expect(!OfflineDownloadRegion.northWest.contains(.midlands))
        #expect(!OfflineDownloadRegion.midlands.contains(.northWest))
        #expect(!OfflineDownloadRegion.northWest.contains(.eastAnglia))
        #expect(!OfflineDownloadRegion.eastAnglia.contains(.northWest))
    }

    @Test func midlandsContainsBirminghamApproach() {
        let box = OfflineDownloadRegion.midlands.boundingBox
        // Birmingham ~52.48, -1.90
        #expect(box.minLat <= 52.48 && 52.48 <= box.maxLat)
        #expect(box.minLon <= -1.90 && -1.90 <= box.maxLon)
        // Northampton ~52.24, -0.90
        #expect(box.minLat <= 52.24 && 52.24 <= box.maxLat)
        #expect(box.minLon <= -0.90 && -0.90 <= box.maxLon)
    }

    @Test func northWestContainsManchesterApproach() {
        let box = OfflineDownloadRegion.northWest.boundingBox
        // Manchester ~53.48, -2.24
        #expect(box.minLat <= 53.48 && 53.48 <= box.maxLat)
        #expect(box.minLon <= -2.24 && -2.24 <= box.maxLon)
        // Liverpool ~53.41, -2.99
        #expect(box.minLat <= 53.41 && 53.41 <= box.maxLat)
        #expect(box.minLon <= -2.99 && -2.99 <= box.maxLon)
        // Preston ~53.76, -2.70
        #expect(box.minLat <= 53.76 && 53.76 <= box.maxLat)
        #expect(box.minLon <= -2.70 && -2.70 <= box.maxLon)
    }

    @Test func areaOrderingNorfolkEastMidlandsUK() {
        let norfolkArea = OfflineDownloadRegion.demoNorfolk.approximateAreaSquareDegrees
        let eastArea = OfflineDownloadRegion.eastAnglia.approximateAreaSquareDegrees
        let midlandsArea = OfflineDownloadRegion.midlands.approximateAreaSquareDegrees
        let northWestArea = OfflineDownloadRegion.northWest.approximateAreaSquareDegrees
        let ukArea = OfflineDownloadRegion.ukCorridor.approximateAreaSquareDegrees
        #expect(eastArea > norfolkArea)
        #expect(midlandsArea > eastArea)
        #expect(northWestArea > eastArea)
        #expect(northWestArea < midlandsArea)
        #expect(midlandsArea < ukArea * 0.08)
        #expect(northWestArea < ukArea * 0.08)
        #expect(eastArea < ukArea * 0.05)
        #expect(OfflineDownloadRegion.ukCorridor.contains(.eastAnglia))
        #expect(OfflineDownloadRegion.ukCorridor.contains(.midlands))
        #expect(OfflineDownloadRegion.ukCorridor.contains(.northWest))
    }

    @Test func allCasesIncludeMidCorridorsBetweenDemoAndUK() {
        let cases = OfflineDownloadRegion.allCases
        #expect(cases.contains(.demoNorfolk))
        #expect(cases.contains(.eastAnglia))
        #expect(cases.contains(.midlands))
        #expect(cases.contains(.northWest))
        #expect(cases.contains(.ukCorridor))
        #expect(cases.count == 5)
    }
}
