#if os(iOS)
import AVFoundation
import Contracts
import Foundation

/// Speaks turn-by-turn navigation prompts using AVSpeechSynthesizer.
@MainActor
public final class NavigationVoiceService: NSObject, @preconcurrency AVSpeechSynthesizerDelegate {
    private let synthesizer = AVSpeechSynthesizer()
    private var currentPriority = 0
    private var isSpeaking = false

    public override init() {
        super.init()
        synthesizer.delegate = self
    }

    /// Configures the audio session for navigation voice guidance.
    public func configureAudioSession() throws {
        let session = AVAudioSession.sharedInstance()
        if #available(iOS 17.0, *) {
            try session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
        } else {
            try session.setCategory(.playback, options: [.duckOthers])
        }
        try session.setActive(true, options: .notifyOthersOnDeactivation)
    }

    /// Deactivates the navigation audio session.
    public func deactivateAudioSession() {
        try? AVAudioSession.sharedInstance().setActive(
            false,
            options: .notifyOthersOnDeactivation
        )
    }

    /// Enqueues a speech prompt respecting priority.
    public func speak(_ prompt: SpeechPrompt) {
        if isSpeaking, prompt.priority <= currentPriority {
            return
        }
        if isSpeaking, prompt.priority > currentPriority {
            synthesizer.stopSpeaking(at: .immediate)
        }

        currentPriority = prompt.priority
        let utterance = AVSpeechUtterance(string: prompt.text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-GB")
        utterance.rate = 0.48
        isSpeaking = true
        synthesizer.speak(utterance)
    }

    /// Stops any in-progress speech.
    public func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        isSpeaking = false
        currentPriority = 0
    }

    public func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didFinish utterance: AVSpeechUtterance
    ) {
        isSpeaking = false
        currentPriority = 0
    }
}
#endif
