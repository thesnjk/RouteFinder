import Foundation

/// Queued speech prompt with priority for navigation voice guidance.
public struct SpeechPrompt: Sendable, Equatable {
    /// Text to speak.
    public let text: String
    /// Speech priority; higher values may interrupt lower tiers.
    public let priority: Int
    /// Announcement tier that produced this prompt.
    public let tier: AnnouncementTier
    /// Instruction identifier for deduplication.
    public let instructionID: UUID

    /// Creates a speech prompt.
    public init(
        text: String,
        priority: Int,
        tier: AnnouncementTier,
        instructionID: UUID
    ) {
        self.text = text
        self.priority = priority
        self.tier = tier
        self.instructionID = instructionID
    }
}
