package com.routefinder.fleetdriver.voice

import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import java.util.Locale
import kotlin.coroutines.resume
import kotlinx.coroutines.suspendCancellableCoroutine

/**
 * Push-to-talk speech recognition that maps short transcripts to [DriverVoiceCommand].
 * Fails soft when the recognizer is unavailable.
 */
class DriverVoiceCommandCoordinator(context: Context) {
    private val appContext = context.applicationContext
    private val mainHandler = Handler(Looper.getMainLooper())
    @Volatile
    var isListening: Boolean = false
        private set

    private var recognizer: SpeechRecognizer? = null
    private var timeoutRunnable: Runnable? = null

    /** Whether on-device speech recognition is available. */
    fun isAvailable(): Boolean = SpeechRecognizer.isRecognitionAvailable(appContext)

    /**
     * Starts a short listen window and returns a matched command when listening ends.
     *
     * @param durationSeconds Maximum listen duration (default 4s).
     */
    suspend fun listen(durationSeconds: Double = 4.0): DriverVoiceCommand? {
        if (isListening) return null
        if (!isAvailable()) return null

        return suspendCancellableCoroutine { continuation ->
            isListening = true
            var latestTranscript = ""
            var finished = false

            fun finish() {
                if (finished) return
                finished = true
                timeoutRunnable?.let { mainHandler.removeCallbacks(it) }
                timeoutRunnable = null
                runCatching { recognizer?.stopListening() }
                runCatching { recognizer?.destroy() }
                recognizer = null
                isListening = false
                if (continuation.isActive) {
                    continuation.resume(DriverVoiceCommandPhraseMatcher.match(latestTranscript))
                }
            }

            continuation.invokeOnCancellation { finish() }

            mainHandler.post {
                val speech = SpeechRecognizer.createSpeechRecognizer(appContext)
                recognizer = speech
                speech.setRecognitionListener(object : RecognitionListener {
                    override fun onReadyForSpeech(params: Bundle?) = Unit
                    override fun onBeginningOfSpeech() = Unit
                    override fun onRmsChanged(rmsdB: Float) = Unit
                    override fun onBufferReceived(buffer: ByteArray?) = Unit
                    override fun onEndOfSpeech() = Unit
                    override fun onError(error: Int) {
                        finish()
                    }

                    override fun onResults(results: Bundle?) {
                        val texts = results
                            ?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                        if (!texts.isNullOrEmpty()) {
                            latestTranscript = texts.first()
                        }
                        finish()
                    }

                    override fun onPartialResults(partialResults: Bundle?) {
                        val texts = partialResults
                            ?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                        if (!texts.isNullOrEmpty()) {
                            latestTranscript = texts.first()
                        }
                    }

                    override fun onEvent(eventType: Int, params: Bundle?) = Unit
                })

                val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
                    putExtra(
                        RecognizerIntent.EXTRA_LANGUAGE_MODEL,
                        RecognizerIntent.LANGUAGE_MODEL_FREE_FORM,
                    )
                    putExtra(RecognizerIntent.EXTRA_LANGUAGE, Locale.UK.toLanguageTag())
                    putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
                    putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 3)
                }
                runCatching { speech.startListening(intent) }
                    .onFailure { finish() }

                val timeout = Runnable { finish() }
                timeoutRunnable = timeout
                mainHandler.postDelayed(timeout, (durationSeconds.coerceAtLeast(1.0) * 1_000).toLong())
            }
        }
    }

    /** Cancels an in-flight listen window. */
    fun cancel() {
        timeoutRunnable?.let { mainHandler.removeCallbacks(it) }
        timeoutRunnable = null
        runCatching { recognizer?.cancel() }
        runCatching { recognizer?.destroy() }
        recognizer = null
        isListening = false
    }
}
