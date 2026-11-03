package com.routefinder.fleetdriver.voice

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

    /** Reply when speech was not recognized as a domain command. */
    const val UNRECOGNIZED = "Sorry, I didn't catch that."
}
