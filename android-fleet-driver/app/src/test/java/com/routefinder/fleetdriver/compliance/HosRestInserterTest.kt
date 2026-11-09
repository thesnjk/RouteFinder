package com.routefinder.fleetdriver.compliance

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class HosRestInserterTest {
    @Test
    fun emptyPathReturnsNoInsertions() {
        val result = HosRestInserter.insertions(
            remainingContinuousDriveSeconds = 3_600.0,
            pathDurationsSeconds = emptyList(),
            upcomingCandidates = listOf(
                HosRestCandidate("a", "A", HosRestCandidateKind.LAYBY, 1_000.0),
            ),
        )
        assertTrue(result.isEmpty())
    }

    @Test
    fun pathFittingBudgetReturnsNoInsertions() {
        val result = HosRestInserter.insertions(
            remainingContinuousDriveSeconds = 10_000.0,
            remainingDailyDriveSeconds = 20_000.0,
            pathDurationsSeconds = listOf(1_000.0, 1_000.0, 1_000.0),
            pathArcLengthsMeters = listOf(10_000.0, 20_000.0, 30_000.0),
            upcomingCandidates = listOf(
                HosRestCandidate("park", "Park", HosRestCandidateKind.OVERNIGHT_SECURE_PARKING, 15_000.0),
            ),
        )
        assertTrue(result.isEmpty())
    }

    @Test
    fun midRouteBudgetExhaustionInsertsBeforeDeadline() {
        val candidates = listOf(
            HosRestCandidate("early", "Early layby", HosRestCandidateKind.LAYBY, 5_000.0),
            HosRestCandidate("fuel", "Fuel", HosRestCandidateKind.HIGH_FLOW_DIESEL, 8_000.0),
            HosRestCandidate("late", "Late park", HosRestCandidateKind.OVERNIGHT_SECURE_PARKING, 25_000.0),
        )
        val result = HosRestInserter.insertions(
            remainingContinuousDriveSeconds = 3_600.0, // 1h
            remainingDailyDriveSeconds = 20_000.0,
            // Three hours of driving in equal chunks → deadline at index 0 after 1h.
            pathDurationsSeconds = listOf(3_600.0, 3_600.0, 3_600.0),
            pathArcLengthsMeters = listOf(10_000.0, 20_000.0, 30_000.0),
            upcomingCandidates = candidates,
        )
        assertEquals(1, result.size)
        val insertion = result.first()
        // Prefer furthest eligible before deadline arc (10 km) → fuel at 8 km beats early layby by distance after kind rank...
        // overnight at 25 km is past deadline arc; fuel (rank 2) vs early layby (rank 1) → layby wins on kind.
        assertEquals("early", insertion.poiId)
        assertTrue(insertion.reason.contains("4.5 h continuous"))
    }

    @Test
    fun prefersOvernightOverLaybyWhenBothEligible() {
        val result = HosRestInserter.insertions(
            remainingContinuousDriveSeconds = 3_600.0,
            pathDurationsSeconds = listOf(3_600.0, 3_600.0),
            pathArcLengthsMeters = listOf(10_000.0, 20_000.0),
            upcomingCandidates = listOf(
                HosRestCandidate("layby", "Layby", HosRestCandidateKind.LAYBY, 4_000.0),
                HosRestCandidate("park", "Secure", HosRestCandidateKind.OVERNIGHT_SECURE_PARKING, 5_000.0),
            ),
        )
        assertEquals(1, result.size)
        assertEquals("park", result.first().poiId)
    }

    @Test
    fun zeroBudgetInsertsImmediateRest() {
        val result = HosRestInserter.insertions(
            remainingContinuousDriveSeconds = 0.0,
            pathDurationsSeconds = listOf(1_000.0),
            pathArcLengthsMeters = listOf(5_000.0),
            upcomingCandidates = listOf(
                HosRestCandidate("now", "Now", HosRestCandidateKind.LAYBY, 100.0),
            ),
        )
        assertEquals(1, result.size)
        assertEquals(-1, result.first().afterSegmentIndex)
        assertTrue(result.first().reason.contains("No remaining drive time"))
    }

    @Test
    fun forecastSummaryIncludesDisclaimerWhenInsertionPresent() {
        val forecast = HosRestInserter.forecast(
            remainingContinuousDriveSeconds = 1_800.0,
            remainingDailyDriveSeconds = 20_000.0,
            pathDurationsSeconds = listOf(3_600.0, 3_600.0),
            pathArcLengthsMeters = listOf(10_000.0, 20_000.0),
            upcomingCandidates = listOf(
                HosRestCandidate("a", "A", HosRestCandidateKind.LAYBY, 2_000.0),
            ),
        )
        assertEquals(1, forecast.insertions.size)
        assertTrue(forecast.summary.contains(HosRestInsertionResult.LEGAL_DISCLAIMER))
    }

    @Test
    fun forecastSummaryNullInsertionsWhenFits() {
        val forecast = HosRestInserter.forecast(
            remainingContinuousDriveSeconds = 20_000.0,
            remainingDailyDriveSeconds = 30_000.0,
            pathDurationsSeconds = listOf(600.0),
            pathArcLengthsMeters = listOf(5_000.0),
            upcomingCandidates = emptyList(),
        )
        assertTrue(forecast.insertions.isEmpty())
        assertTrue(forecast.summary.contains("fits remaining"))
    }

    @Test
    fun highGradeBeforeDeadlineSetsPhysicsPreferred() {
        val result = HosRestInserter.insertions(
            remainingContinuousDriveSeconds = 3_600.0,
            remainingDailyDriveSeconds = 20_000.0,
            pathDurationsSeconds = listOf(3_600.0, 3_600.0, 3_600.0),
            pathArcLengthsMeters = listOf(10_000.0, 20_000.0, 30_000.0),
            upcomingCandidates = listOf(
                HosRestCandidate("pre", "Pre-grade", HosRestCandidateKind.LAYBY, 4_000.0),
                HosRestCandidate("post", "After", HosRestCandidateKind.LAYBY, 18_000.0),
            ),
            kineticStress = listOf(
                HosRestInserter.SegmentKineticStress(thermalStressScore = 0.0, gradePercentage = 1.0),
                HosRestInserter.SegmentKineticStress(thermalStressScore = 0.0, gradePercentage = 8.0),
                HosRestInserter.SegmentKineticStress(thermalStressScore = 0.0, gradePercentage = 0.0),
            ),
        )
        assertEquals(1, result.size)
        assertTrue(result.first().physicsPreferred)
        assertTrue(result.first().reason.contains("upstream"))
        // Prefer POI before high-stress segment (index 1) → arc cap ~10 km → "pre".
        assertEquals("pre", result.first().poiId)
    }

    @Test
    fun highThermalBeforeDeadlineSetsPhysicsPreferred() {
        val result = HosRestInserter.insertions(
            remainingContinuousDriveSeconds = 3_600.0,
            pathDurationsSeconds = listOf(3_600.0, 3_600.0),
            pathArcLengthsMeters = listOf(10_000.0, 20_000.0),
            upcomingCandidates = listOf(
                HosRestCandidate("safe", "Safe", HosRestCandidateKind.OVERNIGHT_SECURE_PARKING, 3_000.0),
            ),
            kineticStress = listOf(
                HosRestInserter.SegmentKineticStress(thermalStressScore = 0.8, gradePercentage = -12.0),
                HosRestInserter.SegmentKineticStress(thermalStressScore = 0.0, gradePercentage = 0.0),
            ),
        )
        assertEquals(1, result.size)
        assertTrue(result.first().physicsPreferred)
        assertTrue(result.first().reason.contains("upstream of high grade/thermal"))
    }

    @Test
    fun advisoryForSiteReturnsMatchingAhead() {
        val route = listOf(
            com.routefinder.fleetdriver.routing.LatLon(52.0, 0.0),
            com.routefinder.fleetdriver.routing.LatLon(52.1, 0.1),
            com.routefinder.fleetdriver.routing.LatLon(52.2, 0.2),
        )
        val site = LaybyAdvisoryEngine.Site(
            id = "mid",
            name = "Mid stop",
            coordinate = com.routefinder.fleetdriver.routing.LatLon(52.1, 0.1),
        )
        val advisory = LaybyAdvisoryEngine.advisoryForSite(
            siteId = "mid",
            route = route,
            currentArcLengthMeters = 0.0,
            sites = listOf(site),
        )
        assertEquals("mid", advisory?.site?.id)
        assertNull(
            LaybyAdvisoryEngine.advisoryForSite(
                siteId = "missing",
                route = route,
                sites = listOf(site),
            ),
        )
    }
}
