package com.routefinder.fleetdriver.voice

import com.routefinder.fleetdriver.compliance.CanIDriveStatus
import com.routefinder.fleetdriver.routing.UKTollAdvisory
import kotlin.math.max
import kotlin.math.roundToInt

/** Spoken confirmation strings for driver voice-assist commands. */
object VoiceAssistResponseFormatter {
    /** Reply after Break Now ranks a layby (or fails). */
    fun breakNow(advisoryMessage: String?): String =
        advisoryMessage?.takeIf { it.isNotBlank() }
            ?: "No laybys found ahead on this route."

    /** Reply after advancing to the next layby (or none remaining). */
    fun nextLayby(advisoryMessage: String?): String =
        advisoryMessage?.takeIf { it.isNotBlank() }
            ?: "No further laybys ahead."

    /** Reply after opening the parking book sheet for an ahead stop. */
    fun bookParking(label: String?, tierLabel: String?): String {
        val name = label?.trim()?.takeIf { it.isNotEmpty() } ?: "Ahead parking"
        return if (!tierLabel.isNullOrBlank()) {
            "Opening book options for $name. Availability: $tierLabel. Partner site — RouteFinder does not take payment."
        } else {
            "Opening book options for $name. Partner site — RouteFinder does not take payment."
        }
    }

    /** Reply when no ahead parking / bookable stop is available. */
    const val BOOK_PARKING_NONE = "No ahead parking to book on this route."

    /** Reply when voice guidance is muted. */
    const val MUTED = "Voice guidance muted."

    /** Reply when voice guidance is restored. */
    const val UNMUTED = "Voice guidance on."

    /** Reply for “where am I stopping?” using layby advisory or destination label. */
    fun whereStopping(advisoryMessage: String?, destinationLabel: String?): String {
        if (!advisoryMessage.isNullOrBlank()) return advisoryMessage
        val trimmed = destinationLabel?.trim().orEmpty()
        if (trimmed.isNotEmpty()) return "Your destination is $trimmed."
        return "No layby planned on this route."
    }

    /** Short spoken Can-I-drive answer (planning aid — not legal VU). */
    fun canIDrive(status: CanIDriveStatus?): String {
        if (status == null) return "Can I drive status is unavailable."
        val remainingMinutes = max(0, (status.remainingContinuousDriveSeconds / 60.0).roundToInt())
        return if (status.canDrive) {
            "Yes. About $remainingMinutes minutes of continuous drive remaining. Planning aid only — check your tachograph."
        } else {
            "No. Do not drive until your tachograph allows. Planning aid only."
        }
    }

    /** Spoken toll callout from the near-horizon advisory or route summary line. */
    fun tollAhead(
        tollName: String?,
        distanceMeters: Double?,
        costLabel: String?,
        routeSummary: String?,
    ): String {
        if (!tollName.isNullOrBlank()) {
            val parts = mutableListOf(tollName)
            if (distanceMeters != null) {
                parts.add(distancePhrase(distanceMeters))
            }
            if (!costLabel.isNullOrBlank()) {
                parts.add(costLabel)
            }
            return parts.joinToString(". ") + ". Indicative only — check the operator."
        }
        if (!routeSummary.isNullOrBlank()) {
            return "$routeSummary. Indicative only — check the operator."
        }
        return "No named tolls on this route."
    }

    /** Route-summary line for UI / commit TTS. Null when no advisories. */
    fun committedRouteTollSummary(advisories: List<UKTollAdvisory>): String? {
        if (advisories.isEmpty()) return null
        val names = advisories.joinToString(" · ") { it.name }
        val total = UKTollAdvisory.indicativeRouteTotalLabel(advisories)
        return if (total != null) "$names — $total" else names
    }

    /** One-shot commit announcement; null when silent (no named tolls). */
    fun committedRouteTollAnnouncement(advisories: List<UKTollAdvisory>): String? {
        val summary = committedRouteTollSummary(advisories) ?: return null
        return tollAhead(
            tollName = null,
            distanceMeters = null,
            costLabel = null,
            routeSummary = summary,
        )
    }

    /** Stable signature for deduping commit-time toll TTS. */
    fun tollRouteSignature(advisories: List<UKTollAdvisory>): String =
        advisories.map { it.id }.sorted().joinToString("|")

    /** Spoken next LEZ / CAZ restriction. */
    fun nextLez(label: String?, message: String?): String {
        if (!message.isNullOrBlank()) return message
        if (!label.isNullOrBlank()) {
            return "$label ahead. Geometry is approximate — not a legal boundary."
        }
        return "No low emission zones flagged on this route."
    }

    /** Spoken remaining ETA from physics or static duration seconds. */
    fun eta(remainingSeconds: Double?): String {
        if (remainingSeconds == null || !remainingSeconds.isFinite() || remainingSeconds <= 0) {
            return "ETA is unavailable."
        }
        return "About ${durationPhrase(remainingSeconds)} remaining."
    }

    /** Spoken hazard / closure callout from the active ahead message. */
    fun hazardAhead(message: String?, distanceMeters: Double?): String {
        if (message.isNullOrBlank()) return "No hazards flagged ahead."
        return if (distanceMeters != null && distanceMeters > 0) {
            "$message ${distancePhrase(distanceMeters)}."
        } else {
            message
        }
    }

    /** Spoken roadworks callout. */
    fun roadworksAhead(message: String?, distanceMeters: Double?): String {
        if (message.isNullOrBlank()) return "No roadworks flagged ahead."
        return if (distanceMeters != null && distanceMeters > 0) {
            "$message ${distancePhrase(distanceMeters)}."
        } else {
            message
        }
    }

    /** Spoken primary fused predictive-risk advisory. */
    fun riskAhead(message: String?): String {
        val trimmed = message?.trim().orEmpty()
        if (trimmed.isNotEmpty()) return trimmed
        return "No predictive risks flagged ahead."
    }

    /** Reply when speech was not recognized as a domain command. */
    const val UNRECOGNIZED = "Sorry, I didn't catch that."

    private fun distancePhrase(meters: Double): String =
        if (meters >= 1000) {
            String.format("in %.1f kilometres", meters / 1000.0)
        } else {
            "in ${meters.toInt()} metres"
        }

    private fun durationPhrase(seconds: Double): String {
        val totalMinutes = max(1, (seconds / 60.0).roundToInt())
        val hours = totalMinutes / 60
        val minutes = totalMinutes % 60
        return if (hours > 0) {
            "$hours hours $minutes minutes"
        } else {
            "$minutes minutes"
        }
    }
}
