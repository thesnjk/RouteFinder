package com.routefinder.fleetdriver.physics

import com.routefinder.fleetdriver.compliance.HosRestInserter
import com.routefinder.fleetdriver.routing.LatLon
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import kotlin.math.abs

class KineticGradientAnalyzerTest {
    @Test
    fun flatPathHasNearZeroThermalAndGrade() {
        val path = listOf(
            LatLon(52.0, 0.0, elevationMeters = 100.0),
            LatLon(52.01, 0.0, elevationMeters = 100.0),
            LatLon(52.02, 0.0, elevationMeters = 100.5),
        )
        val stress = KineticGradientAnalyzer.analyzeTopology(path, weightTons = 40.0)
        assertEquals(2, stress.size)
        assertTrue(stress.all { it.thermalStressScore < 0.05 })
        assertTrue(stress.all { abs(it.gradePercentage) < 2.0 })
    }

    @Test
    fun steepDescentRaisesThermalStress() {
        // ~1.1 km north; 200 m drop → ~18% grade.
        val path = listOf(
            LatLon(52.0, 0.0, elevationMeters = 400.0),
            LatLon(52.01, 0.0, elevationMeters = 200.0),
        )
        val stress = KineticGradientAnalyzer.analyzeTopology(path, weightTons = 44.0)
        assertEquals(1, stress.size)
        assertTrue(stress[0].gradePercentage < -2.0)
        assertTrue(
            "thermal=${stress[0].thermalStressScore}",
            stress[0].thermalStressScore >= HosRestInserter.THERMAL_STRESS_THRESHOLD,
        )
    }

    @Test
    fun climbYieldsPositiveGradePercent() {
        val path = listOf(
            LatLon(52.0, 0.0, elevationMeters = 50.0),
            LatLon(52.01, 0.0, elevationMeters = 150.0),
        )
        val stress = KineticGradientAnalyzer.analyzeTopology(path, weightTons = 40.0)
        assertEquals(1, stress.size)
        assertTrue(stress[0].gradePercentage > 2.0)
        assertEquals(0.0, stress[0].thermalStressScore, 0.001)
    }

    @Test
    fun alignToSegmentCountPadsAndTruncates() {
        val one = listOf(
            HosRestInserter.SegmentKineticStress(0.9, -10.0),
        )
        val padded = KineticGradientAnalyzer.alignToSegmentCount(one, 3)
        assertEquals(3, padded.size)
        assertEquals(0.9, padded[0].thermalStressScore, 0.001)
        assertEquals(0.0, padded[2].thermalStressScore, 0.001)

        val many = listOf(
            KineticGradientAnalyzer.NEUTRAL,
            KineticGradientAnalyzer.NEUTRAL,
            KineticGradientAnalyzer.NEUTRAL,
        )
        assertEquals(2, KineticGradientAnalyzer.alignToSegmentCount(many, 2).size)
    }
}
