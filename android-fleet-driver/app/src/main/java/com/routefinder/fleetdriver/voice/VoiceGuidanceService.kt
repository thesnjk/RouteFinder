package com.routefinder.fleetdriver.voice

import android.content.Context
import android.speech.tts.TextToSpeech
import com.routefinder.fleetdriver.nav.AnnouncementTier
import com.routefinder.fleetdriver.nav.TurnInstruction
import java.util.Locale

/** Android TTS wrapper for metric turn-by-turn prompts. */
class VoiceGuidanceService(context: Context) : TextToSpeech.OnInitListener {
    private var tts: TextToSpeech? = TextToSpeech(context.applicationContext, this)
    private var ready = false
    var enabled: Boolean = true

    private val announcementGate = ManeuverAnnouncementGate()

    override fun onInit(status: Int) {
        ready = status == TextToSpeech.SUCCESS
        if (ready) {
            tts?.language = Locale.UK
        }
    }

    fun resetAnnouncements() {
        announcementGate.reset()
    }

    /**
     * Clears prepare for [maneuverIndex] after heuristic→OSM lane upgrade (iOS parity).
     * No-ops if execute already spoken for that index.
     */
    fun invalidatePrepareForLaneUpgrade(maneuverIndex: Int) {
        announcementGate.invalidatePrepareForLaneUpgrade(maneuverIndex)
    }

    fun onProgress(
        instruction: TurnInstruction?,
        maneuverIndex: Int,
        distanceToNextMeters: Double,
    ) {
        if (!enabled || !ready || instruction == null) return
        if (ManeuverSpeechFormatter.shouldSuppressVoice(instruction.maneuver, AnnouncementTier.EXECUTE) &&
            distanceToNextMeters > 50
        ) {
            return
        }
        when {
            distanceToNextMeters <= 40.0 && announcementGate.shouldAnnounceExecute(maneuverIndex) -> {
                if (!ManeuverSpeechFormatter.shouldSuppressVoice(instruction.maneuver, AnnouncementTier.EXECUTE)) {
                    speak(ManeuverSpeechFormatter.spokenPrompt(instruction, AnnouncementTier.EXECUTE))
                }
                announcementGate.markExecute(maneuverIndex)
            }
            distanceToNextMeters in 40.0..450.0 && announcementGate.shouldAnnouncePrepare(maneuverIndex) -> {
                if (!ManeuverSpeechFormatter.shouldSuppressVoice(instruction.maneuver, AnnouncementTier.PREPARE)) {
                    speak(ManeuverSpeechFormatter.spokenPrompt(instruction, AnnouncementTier.PREPARE))
                }
                announcementGate.markPrepare(maneuverIndex)
            }
            distanceToNextMeters in 450.0..1700.0 && announcementGate.shouldAnnounceApproach(maneuverIndex) -> {
                if (!ManeuverSpeechFormatter.shouldSuppressVoice(instruction.maneuver, AnnouncementTier.APPROACH)) {
                    speak(ManeuverSpeechFormatter.spokenPrompt(instruction, AnnouncementTier.APPROACH))
                }
                announcementGate.markApproach(maneuverIndex)
            }
        }
    }

    fun speak(text: String) {
        if (!enabled || !ready || text.isBlank()) return
        speakAssist(text)
    }

    /** Speaks assist replies even when turn-by-turn guidance is muted. */
    fun speakAssist(text: String) {
        if (!ready || text.isBlank()) return
        tts?.speak(text, TextToSpeech.QUEUE_ADD, null, "rf-${System.currentTimeMillis()}")
    }

    fun shutdown() {
        tts?.stop()
        tts?.shutdown()
        tts = null
        ready = false
    }
}
