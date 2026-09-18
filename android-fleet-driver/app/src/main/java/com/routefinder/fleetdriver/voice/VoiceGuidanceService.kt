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

    private var lastApproachIndex: Int? = null
    private var lastPrepareIndex: Int? = null
    private var lastExecuteIndex: Int? = null

    override fun onInit(status: Int) {
        ready = status == TextToSpeech.SUCCESS
        if (ready) {
            tts?.language = Locale.UK
        }
    }

    fun resetAnnouncements() {
        lastApproachIndex = null
        lastPrepareIndex = null
        lastExecuteIndex = null
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
            distanceToNextMeters <= 40.0 && lastExecuteIndex != maneuverIndex -> {
                if (!ManeuverSpeechFormatter.shouldSuppressVoice(instruction.maneuver, AnnouncementTier.EXECUTE)) {
                    speak(ManeuverSpeechFormatter.spokenPrompt(instruction, AnnouncementTier.EXECUTE))
                }
                lastExecuteIndex = maneuverIndex
            }
            distanceToNextMeters in 40.0..450.0 && lastPrepareIndex != maneuverIndex -> {
                if (!ManeuverSpeechFormatter.shouldSuppressVoice(instruction.maneuver, AnnouncementTier.PREPARE)) {
                    speak(ManeuverSpeechFormatter.spokenPrompt(instruction, AnnouncementTier.PREPARE))
                }
                lastPrepareIndex = maneuverIndex
            }
            distanceToNextMeters in 450.0..1700.0 && lastApproachIndex != maneuverIndex -> {
                if (!ManeuverSpeechFormatter.shouldSuppressVoice(instruction.maneuver, AnnouncementTier.APPROACH)) {
                    speak(ManeuverSpeechFormatter.spokenPrompt(instruction, AnnouncementTier.APPROACH))
                }
                lastApproachIndex = maneuverIndex
            }
        }
    }

    fun speak(text: String) {
        if (!enabled || !ready || text.isBlank()) return
        tts?.speak(text, TextToSpeech.QUEUE_ADD, null, "rf-${System.currentTimeMillis()}")
    }

    fun shutdown() {
        tts?.stop()
        tts?.shutdown()
        tts = null
        ready = false
    }
}
