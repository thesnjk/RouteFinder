#if os(iOS)
import AVFoundation
import Contracts
import Testing
@testable import UI

@Suite("Navigation voice service")
struct NavigationVoiceServiceTests {
    @Test @MainActor func queueAcceptsMultiplePrompts() {
        let service = NavigationVoiceService()
        let first = SpeechPrompt(
            text: "In 400 metres, turn left",
            priority: AnnouncementTier.prepare.priority,
            tier: .prepare,
            instructionID: UUID()
        )
        let second = SpeechPrompt(
            text: "Turn right",
            priority: AnnouncementTier.execute.priority,
            tier: .execute,
            instructionID: UUID()
        )
        service.speak(first)
        service.speak(second)
        service.stop()
    }
}
#endif
