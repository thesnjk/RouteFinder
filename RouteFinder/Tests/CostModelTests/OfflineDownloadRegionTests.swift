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

    @Test func eastAngliaContainsNorfolkDemoCenter() {
        let norfolk = OfflineDownloadRegion.demoNorfolk.boundingBox
        let centerLat = (norfolk.minLat + norfolk.maxLat) / 2
        let centerLon = (norfolk.minLon + norfolk.maxLon) / 2
        let east = OfflineDownloadRegion.eastAnglia.boundingBox
        #expect(east.minLat <= centerLat && centerLat <= east.maxLat)
        #expect(east.minLon <= centerLon && centerLon <= east.maxLon)
        #expect(OfflineDownloadRegion.eastAnglia.contains(.demoNorfolk))
    }

    @Test func eastAngliaAreaMuchSmallerThanUKMainland() {
        let eastArea = OfflineDownloadRegion.eastAnglia.approximateAreaSquareDegrees
        let ukArea = OfflineDownloadRegion.ukCorridor.approximateAreaSquareDegrees
        let norfolkArea = OfflineDownloadRegion.demoNorfolk.approximateAreaSquareDegrees
        #expect(eastArea > norfolkArea)
        #expect(eastArea < ukArea * 0.05)
        #expect(OfflineDownloadRegion.ukCorridor.contains(.eastAnglia))
    }

    @Test func allCasesIncludeMidCorridorBetweenDemoAndUK() {
        let cases = OfflineDownloadRegion.allCases
        #expect(cases.contains(.demoNorfolk))
        #expect(cases.contains(.eastAnglia))
        #expect(cases.contains(.ukCorridor))
        #expect(cases.count == 3)
    }
}
