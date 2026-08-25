import Contracts
import CostModel
import Foundation

/// Advisory EU Regulation 561 / Working Time Directive hours-of-service clock.
///
/// Tracks continuous, daily, weekly, and fortnight driving remaining; persists a
/// duty log to disk; and forecasts rest insertions for planned paths.
///
/// The digital tachograph remains the legal record — see
/// ``HosRestInsertionResult/legalDisclaimer``.
public actor EU561HosClock: HosClockPort {
    /// Continuous driving limit before a break (4.5 h).
    public static let continuousDriveLimitSeconds: TimeInterval = 4.5 * 3600
    /// Mandatory break after continuous limit (45 min).
    public static let continuousBreakSeconds: TimeInterval = 45 * 60
    /// Standard daily driving limit (9 h).
    public static let dailyDriveLimitSeconds: TimeInterval = 9 * 3600
    /// Extended daily driving limit (10 h), once per week.
    public static let dailyDriveExtendedLimitSeconds: TimeInterval = 10 * 3600
    /// Weekly driving limit (56 h).
    public static let weeklyDriveLimitSeconds: TimeInterval = 56 * 3600
    /// Fortnight driving limit (90 h).
    public static let fortnightDriveLimitSeconds: TimeInterval = 90 * 3600
    /// Working Time Directive weekly heads-up threshold (60 h).
    public static let wtdWeeklyHeadsUpSeconds: TimeInterval = 60 * 3600

    private let fileURL: URL
    private let alertBus: InMemoryDriverAlertBus?
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private var mode: HosDutyMode = .offDuty
    private var remainingContinuousDriveSeconds: TimeInterval = continuousDriveLimitSeconds
    private var remainingDailyDriveSeconds: TimeInterval = dailyDriveLimitSeconds
    private var remainingWeeklyDriveSeconds: TimeInterval = weeklyDriveLimitSeconds
    private var remainingFortnightDriveSeconds: TimeInterval = fortnightDriveLimitSeconds
    private var usedDailyExtensionThisWeek = false
    private var weekWorkedSeconds: TimeInterval = 0
    private var dutyLog: [HosDutyEvent] = []
    private var lastTransitionAt: Date
    private var clock: () -> Date

    /// Creates an advisory HOS clock with optional custom storage and alert bus.
    ///
    /// - Parameters:
    ///   - storageDirectory: Directory for the JSON duty log (defaults to Application Support).
    ///   - alertBus: Optional bus for publishing HOS heads-up alerts.
    ///   - now: Clock injection for tests.
    public init(
        storageDirectory: URL? = nil,
        alertBus: InMemoryDriverAlertBus? = nil,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.alertBus = alertBus
        self.clock = now
        self.lastTransitionAt = now()

        let directory: URL
        if let storageDirectory {
            directory = storageDirectory
        } else {
            let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            directory = support.appendingPathComponent("RouteFinder/hos", isDirectory: true)
        }
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        self.fileURL = directory.appendingPathComponent("duty_log.json")
        self.encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.encoder.dateEncodingStrategy = .iso8601
        self.decoder.dateDecodingStrategy = .iso8601
    }

    /// Loads a previously persisted duty log (if any) without changing remaining budgets.
    public func loadPersistedLog() {
        guard let data = try? Data(contentsOf: fileURL),
              let persisted = try? decoder.decode(PersistedState.self, from: data) else {
            return
        }
        dutyLog = persisted.events
        mode = persisted.mode
        remainingContinuousDriveSeconds = persisted.remainingContinuousDriveSeconds
        remainingDailyDriveSeconds = persisted.remainingDailyDriveSeconds
        remainingWeeklyDriveSeconds = persisted.remainingWeeklyDriveSeconds
        remainingFortnightDriveSeconds = persisted.remainingFortnightDriveSeconds
        usedDailyExtensionThisWeek = persisted.usedDailyExtensionThisWeek
        weekWorkedSeconds = persisted.weekWorkedSeconds
        lastTransitionAt = persisted.lastTransitionAt
    }

    /// Transitions duty mode, accrues elapsed time for the previous mode, and persists the log.
    public func transition(mode event: HosDutyEvent) async throws -> HosDutyMode {
        accrue(until: event.at)
        let previous = mode
        mode = event.mode
        lastTransitionAt = event.at
        dutyLog.append(event)

        switch event.mode {
        case .breakRest:
            remainingContinuousDriveSeconds = Self.continuousDriveLimitSeconds
        case .offDuty:
            remainingContinuousDriveSeconds = Self.continuousDriveLimitSeconds
            // Advisory: treating a fresh off-duty period as a new daily window.
            remainingDailyDriveSeconds = Self.dailyDriveLimitSeconds
        case .driving, .otherWork, .availability:
            break
        }

        try persist()
        await publishTransitionAlert(from: previous, to: event.mode)
        return mode
    }

    /// Forecasts rest insertions when the path would exceed remaining continuous or daily drive.
    public func forecast(pathDurationsSeconds: [TimeInterval]) async -> HosRestInsertionResult {
        accrue(until: clock())
        let insertions = HosRestInserter.insertions(
            remainingContinuousDriveSeconds: remainingContinuousDriveSeconds,
            remainingDailyDriveSeconds: remainingDailyDriveSeconds,
            pathDurationsSeconds: pathDurationsSeconds,
            upcomingTruckPois: [],
            kineticStress: nil,
            restDurationSeconds: Self.continuousBreakSeconds
        )
        return HosRestInsertionResult(
            remainingContinuousDriveSeconds: remainingContinuousDriveSeconds,
            remainingDailyDriveSeconds: remainingDailyDriveSeconds,
            insertions: insertions,
            summary: buildSummary(pathDurationsSeconds: pathDurationsSeconds, insertions: insertions)
        )
    }

    /// Returns the current advisory snapshot for HUD display.
    public func snapshot() async -> HosClockSnapshot {
        accrue(until: clock())
        return HosClockSnapshot(
            mode: mode,
            remainingContinuousDriveSeconds: remainingContinuousDriveSeconds,
            remainingDailyDriveSeconds: remainingDailyDriveSeconds,
            remainingWeeklyDriveSeconds: remainingWeeklyDriveSeconds,
            updatedAt: clock()
        )
    }

    /// Remaining fortnight driving seconds (for tests / advanced HUD).
    public func remainingFortnightSeconds() -> TimeInterval {
        remainingFortnightDriveSeconds
    }

    /// Whether the once-per-week 10 h daily extension has been used.
    public func hasUsedDailyExtensionThisWeek() -> Bool {
        usedDailyExtensionThisWeek
    }

    /// Activates the once-per-week daily extension to 10 h (advisory).
    public func activateDailyExtension() {
        guard !usedDailyExtensionThisWeek else { return }
        usedDailyExtensionThisWeek = true
        let alreadyDrivenToday = Self.dailyDriveLimitSeconds - remainingDailyDriveSeconds
        remainingDailyDriveSeconds = max(
            0,
            Self.dailyDriveExtendedLimitSeconds - max(0, alreadyDrivenToday)
        )
        try? persist()
    }

    /// Returns the persisted duty events.
    public func dutyEvents() -> [HosDutyEvent] {
        dutyLog
    }

    // MARK: - Private

    private func accrue(until now: Date) {
        let elapsed = max(0, now.timeIntervalSince(lastTransitionAt))
        guard elapsed > 0 else { return }
        lastTransitionAt = now

        switch mode {
        case .driving:
            remainingContinuousDriveSeconds = max(0, remainingContinuousDriveSeconds - elapsed)
            remainingDailyDriveSeconds = max(0, remainingDailyDriveSeconds - elapsed)
            remainingWeeklyDriveSeconds = max(0, remainingWeeklyDriveSeconds - elapsed)
            remainingFortnightDriveSeconds = max(0, remainingFortnightDriveSeconds - elapsed)
            weekWorkedSeconds += elapsed
        case .otherWork, .availability:
            weekWorkedSeconds += elapsed
        case .breakRest, .offDuty:
            break
        }
    }

    private func buildSummary(
        pathDurationsSeconds: [TimeInterval],
        insertions: [HosRestInsertion]
    ) -> String {
        let pathTotal = pathDurationsSeconds.reduce(0, +)
        var parts: [String] = []
        parts.append(
            "Continuous remaining \(formatHours(remainingContinuousDriveSeconds)); daily \(formatHours(remainingDailyDriveSeconds)); week \(formatHours(remainingWeeklyDriveSeconds))."
        )
        if !insertions.isEmpty {
            parts.append("Suggest \(insertions.count) rest stop(s) on this path (\(formatHours(pathTotal)) drive).")
        } else if pathTotal > 0 {
            parts.append("Path of \(formatHours(pathTotal)) fits current remaining drive.")
        }
        if weekWorkedSeconds >= Self.wtdWeeklyHeadsUpSeconds {
            parts.append("WTD heads-up: weekly working time ≥ 60 h.")
        }
        parts.append(HosRestInsertionResult.legalDisclaimer)
        return parts.joined(separator: " ")
    }

    private func formatHours(_ seconds: TimeInterval) -> String {
        let totalMinutes = max(0, Int((seconds / 60).rounded()))
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }

    private func publishTransitionAlert(from previous: HosDutyMode, to next: HosDutyMode) async {
        guard let alertBus else { return }
        if next == .driving, remainingContinuousDriveSeconds < 30 * 60 {
            await alertBus.publish(
                DriverAlert(
                    kind: .hos,
                    title: "Low continuous drive",
                    message: "Under 30 minutes of continuous drive remaining. Plan a 45 min break."
                )
            )
        }
        if previous != next {
            await alertBus.publish(
                DriverAlert(
                    kind: .hos,
                    title: "Duty mode: \(next.displayName)",
                    message: HosRestInsertionResult.legalDisclaimer,
                    speakable: false
                )
            )
        }
    }

    private func persist() throws {
        let state = PersistedState(
            events: dutyLog,
            mode: mode,
            remainingContinuousDriveSeconds: remainingContinuousDriveSeconds,
            remainingDailyDriveSeconds: remainingDailyDriveSeconds,
            remainingWeeklyDriveSeconds: remainingWeeklyDriveSeconds,
            remainingFortnightDriveSeconds: remainingFortnightDriveSeconds,
            usedDailyExtensionThisWeek: usedDailyExtensionThisWeek,
            weekWorkedSeconds: weekWorkedSeconds,
            lastTransitionAt: lastTransitionAt
        )
        let data = try encoder.encode(state)
        try data.write(to: fileURL, options: .atomic)
    }

    private struct PersistedState: Codable {
        let events: [HosDutyEvent]
        let mode: HosDutyMode
        let remainingContinuousDriveSeconds: TimeInterval
        let remainingDailyDriveSeconds: TimeInterval
        let remainingWeeklyDriveSeconds: TimeInterval
        let remainingFortnightDriveSeconds: TimeInterval
        let usedDailyExtensionThisWeek: Bool
        let weekWorkedSeconds: TimeInterval
        let lastTransitionAt: Date
    }
}
