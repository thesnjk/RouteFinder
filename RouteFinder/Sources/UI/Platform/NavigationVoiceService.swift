#if os(iOS)
import AVFoundation
import Contracts
import Foundation

/// Speaks turn-by-turn navigation prompts using AVSpeechSynthesizer.
@MainActor
public final class NavigationVoiceService: NSObject, @preconcurrency AVSpeechSynthesizerDelegate {
    private let synthesizer = AVSpeechSynthesizer()
    private var pendingQueue: [SpeechPrompt] = []
    private var currentPriority = 0
    private var isSpeaking = false
    private var cachedVoice: AVSpeechSynthesisVoice?
    private var audioSessionConfigured = false

    private let maxQueueSize = 3

    public override init() {
        super.init()
        synthesizer.delegate = self
    }

    /// Configures the audio session for navigation voice guidance.
    public func configureAudioSession() throws {
        guard !audioSessionConfigured else { return }
        let session = AVAudioSession.sharedInstance()
        if #available(iOS 17.0, *) {
            try session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
        } else {
            try session.setCategory(.playback, options: [.duckOthers])
        }
        try session.setActive(true, options: .notifyOthersOnDeactivation)
        audioSessionConfigured = true
    }

    /// Deactivates the navigation audio session.
    public func deactivateAudioSession() {
        synthesizer.stopSpeaking(at: .immediate)
        isSpeaking = false
        currentPriority = 0
        pendingQueue.removeAll()
        audioSessionConfigured = false
        try? AVAudioSession.sharedInstance().setActive(
            false,
            options: .notifyOthersOnDeactivation
        )
    }

    /// Enqueues a speech prompt respecting priority.
    public func speak(_ prompt: SpeechPrompt) {
        if isSpeaking {
            if prompt.priority <= currentPriority {
                if prompt.tier != .execute, pendingQueue.count < maxQueueSize {
                    pendingQueue.append(prompt)
                }
                return
            }
            synthesizer.stopSpeaking(at: prompt.tier == .execute ? .immediate : .word)
        }
        deliver(prompt)
    }

    /// Stops any in-progress speech.
    public func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        isSpeaking = false
        currentPriority = 0
        pendingQueue.removeAll()
    }

    public func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didFinish utterance: AVSpeechUtterance
    ) {
        isSpeaking = false
        currentPriority = 0
        if let next = pendingQueue.first {
            pendingQueue.removeFirst()
            deliver(next)
        }
    }

    private func deliver(_ prompt: SpeechPrompt) {
        currentPriority = prompt.priority
        let utterance = AVSpeechUtterance(string: prompt.text)
        utterance.voice = resolvedVoice()
        utterance.rate = Float(NavigationWorkspaceSettings.loadSpeechRate())
        utterance.preUtteranceDelay = 0.08
        utterance.postUtteranceDelay = 0.12
        isSpeaking = true
        synthesizer.speak(utterance)
    }

    private func resolvedVoice() -> AVSpeechSynthesisVoice? {
        if let identifier = NavigationWorkspaceSettings.loadSpeechVoiceIdentifier(),
           let voice = AVSpeechSynthesisVoice(identifier: identifier) {
            return voice
        }
        if let cachedVoice {
            return cachedVoice
        }
        let enhanced = AVSpeechSynthesisVoice.speechVoices().first { voice in
            voice.language.hasPrefix("en") && voice.quality == .enhanced
        }
        let voice = enhanced ?? AVSpeechSynthesisVoice(language: "en-GB")
        cachedVoice = voice
        return voice
    }
}
#endif
