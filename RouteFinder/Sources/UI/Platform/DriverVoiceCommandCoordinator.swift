#if os(iOS)
import AVFoundation
import Contracts
import Foundation
import Speech

/// Push-to-talk speech recognition that maps short transcripts to ``DriverVoiceCommand``.
@MainActor
public final class DriverVoiceCommandCoordinator {
    /// Whether a listen window is currently active.
    public private(set) var isListening = false

    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-GB"))
      ?? SFSpeechRecognizer()
    private let audioEngine = AVAudioEngine()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var listenTimeoutTask: Task<Void, Never>?
    private var listenEndContinuation: CheckedContinuation<Void, Never>?
    private var latestTranscript = ""

    /// Creates a push-to-talk voice command coordinator.
    public init() {}

    /// Requests speech + microphone authorization when needed.
    public func ensureAuthorized() async -> Bool {
        let speechStatus = await withCheckedContinuation { (continuation: CheckedContinuation<SFSpeechRecognizerAuthorizationStatus, Never>) in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
        guard speechStatus == .authorized else { return false }

        let micGranted = await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
            AVAudioApplication.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
        return micGranted
    }

    /// Starts a short listen window and returns a matched command when listening ends.
    ///
    /// - Parameter durationSeconds: Maximum listen duration (default 4s).
    public func listen(durationSeconds: TimeInterval = 4.0) async -> DriverVoiceCommand? {
        guard !isListening else { return nil }
        guard speechRecognizer?.isAvailable == true else { return nil }
        guard await ensureAuthorized() else { return nil }

        latestTranscript = ""
        isListening = true

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            listenEndContinuation = continuation

            let request = SFSpeechAudioBufferRecognitionRequest()
            request.shouldReportPartialResults = true
            request.taskHint = .dictation
            recognitionRequest = request

            let inputNode = audioEngine.inputNode
            let format = inputNode.outputFormat(forBus: 0)
            inputNode.removeTap(onBus: 0)
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
                self?.recognitionRequest?.append(buffer)
            }

            do {
                let session = AVAudioSession.sharedInstance()
                try session.setCategory(
                    .playAndRecord,
                    mode: .measurement,
                    options: [.duckOthers, .defaultToSpeaker]
                )
                try session.setActive(true, options: .notifyOthersOnDeactivation)
                audioEngine.prepare()
                try audioEngine.start()
            } catch {
                self.finishListening()
                return
            }

            recognitionTask = speechRecognizer?.recognitionTask(with: request) { [weak self] result, _ in
                guard let self, let result else { return }
                Task { @MainActor in
                    self.latestTranscript = result.bestTranscription.formattedString
                }
            }

            listenTimeoutTask = Task { @MainActor in
                try? await Task.sleep(nanoseconds: UInt64(max(durationSeconds, 1) * 1_000_000_000))
                guard !Task.isCancelled else { return }
                self.finishListening()
            }
        }

        return DriverVoiceCommandPhraseMatcher.match(latestTranscript)
    }

    /// Cancels an in-flight listen window without waiting for the timeout.
    public func cancel() {
        finishListening()
    }

    private func finishListening() {
        listenTimeoutTask?.cancel()
        listenTimeoutTask = nil
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        recognitionTask?.cancel()
        recognitionTask = nil
        isListening = false
        if let continuation = listenEndContinuation {
            listenEndContinuation = nil
            continuation.resume()
        }
    }
}
#endif
