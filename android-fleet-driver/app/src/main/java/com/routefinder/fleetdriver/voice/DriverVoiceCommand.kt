package com.routefinder.fleetdriver.voice

/** Domain voice commands for hands-free driver assist (push-to-talk). */
enum class DriverVoiceCommand {
    /** Rank nearest layby ahead (Break Now). */
    BREAK_NOW,

    /** Skip current layby and advance to the next candidate. */
    NEXT_LAYBY,

    /** Mute turn-by-turn and proactive voice guidance. */
    MUTE,

    /** Restore voice guidance. */
    UNMUTE,

    /** Ask which layby / destination the driver is stopping at. */
    WHERE_STOPPING,

    /** Ask whether the advisory HOS / card budget still allows driving. */
    CAN_I_DRIVE,

    /** Ask about named UK tolls on the active route. */
    TOLL_AHEAD,

    /** Ask about the next LEZ / CAZ restriction on the route. */
    NEXT_LEZ,

    /** Ask for remaining ETA. */
    ETA,

    /** Ask about hazards / closures ahead on the route. */
    HAZARD_AHEAD,

    /** Ask about roadworks / construction ahead. */
    ROADWORKS_AHEAD,

    /** Ask about the primary fused predictive-risk advisory. */
    RISK_AHEAD,

    /** Open the ahead parking book sheet (TRAVIS-first deep link). */
    BOOK_PARKING,
}

/** Matches normalized speech transcripts to [DriverVoiceCommand] values. */
object DriverVoiceCommandPhraseMatcher {
    private val ranked: List<Pair<DriverVoiceCommand, List<String>>> = listOf(
        DriverVoiceCommand.BOOK_PARKING to listOf(
            "book parking",
            "reserve parking",
            "book a parking",
            "book truck stop",
            "book a truck stop",
            "book a layby bay",
            "book layby bay",
        ),
        DriverVoiceCommand.BREAK_NOW to listOf(
            "break now",
            "find a layby",
            "find layby",
            "find a rest stop",
            "need a break",
            "i need a break",
        ),
        DriverVoiceCommand.NEXT_LAYBY to listOf(
            "next layby",
            "skip this layby",
            "skip layby",
            "layby is full",
            "this layby is full",
            "looks full",
        ),
        DriverVoiceCommand.UNMUTE to listOf(
            "unmute",
            "voice on",
            "turn voice on",
            "enable voice",
        ),
        DriverVoiceCommand.MUTE to listOf(
            "mute",
            "be quiet",
            "silence",
            "voice off",
            "turn voice off",
            "stop talking",
        ),
        DriverVoiceCommand.WHERE_STOPPING to listOf(
            "where am i stopping",
            "where am i stopping?",
            "next stop",
            "where is my stop",
            "whats my stop",
            "what's my stop",
            "where am i going",
        ),
        DriverVoiceCommand.CAN_I_DRIVE to listOf(
            "can i drive",
            "can i drive now",
            "am i legal to drive",
            "am i allowed to drive",
            "can i keep driving",
            "how much drive time left",
        ),
        DriverVoiceCommand.TOLL_AHEAD to listOf(
            "any tolls",
            "toll ahead",
            "any tolls ahead",
            "are there tolls",
            "tolls on this route",
            "what tolls",
        ),
        DriverVoiceCommand.NEXT_LEZ to listOf(
            "next lez",
            "low emission zone",
            "clean air zone",
            "any caz",
            "any lez",
            "emission zone ahead",
            "ulez ahead",
        ),
        DriverVoiceCommand.ETA to listOf(
            "what's my eta",
            "whats my eta",
            "what is my eta",
            "how long left",
            "how long until i arrive",
            "arrival time",
            "eta",
        ),
        DriverVoiceCommand.ROADWORKS_AHEAD to listOf(
            "any roadworks",
            "roadworks ahead",
            "any roadworks ahead",
            "construction ahead",
            "any construction",
            "road works ahead",
        ),
        DriverVoiceCommand.HAZARD_AHEAD to listOf(
            "any hazards",
            "hazard ahead",
            "any hazards ahead",
            "any closures",
            "closure ahead",
            "road closed ahead",
            "what's ahead",
            "whats ahead",
        ),
        DriverVoiceCommand.RISK_AHEAD to listOf(
            "any risks",
            "what's the risk",
            "whats the risk",
            "what is the risk",
            "traffic risk",
            "risk ahead",
            "any risk ahead",
        ),
    )

    /** Returns the best matching command, or null when unrecognized. */
    fun match(transcript: String): DriverVoiceCommand? {
        val normalized = normalize(transcript)
        if (normalized.isEmpty()) return null

        var best: Pair<DriverVoiceCommand, Int>? = null
        for ((command, phrases) in ranked) {
            for (phrase in phrases) {
                val phraseNorm = normalize(phrase)
                if (normalized == phraseNorm || normalized.contains(phraseNorm)) {
                    val score = phraseNorm.length
                    if (best == null || score > best.second) {
                        best = command to score
                    }
                }
            }
        }
        return best?.first
    }

    /** Lowercases, strips punctuation, and collapses whitespace. */
    fun normalize(transcript: String): String =
        transcript
            .lowercase()
            .replace(Regex("[^a-z0-9\\s']"), " ")
            .replace(Regex("\\s+"), " ")
            .trim()
}
