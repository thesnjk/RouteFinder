import FleetServerCore
import Foundation
import Testing

@Suite("Fleet proxy usage meter")
struct FleetProxyUsageMeterTests {
    @Test("Allows requests under hard daily caps and blocks when exceeded")
    func hardCaps() async {
        let meter = FleetProxyUsageMeter(
            budget: FleetProxyUsageBudget(routeDailyCap: 2, geocodeDailyCap: 1)
        )
        #expect(await meter.allows(.orsRoute))
        await meter.record(.orsRoute)
        #expect(await meter.allows(.orsRoute))
        await meter.record(.orsRoute)
        #expect(await meter.allows(.orsRoute) == false)

        #expect(await meter.allows(.orsGeocode))
        await meter.record(.orsGeocode)
        #expect(await meter.allows(.orsGeocode) == false)

        let status = await meter.status(orsConfigured: true)
        #expect(status.orsConfigured)
        #expect(status.routesToday == 2)
        #expect(status.routeDailyCap == 2)
        #expect(status.geocodeToday == 1)
    }
}
