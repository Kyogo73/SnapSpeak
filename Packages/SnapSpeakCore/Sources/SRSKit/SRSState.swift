import Foundation

/// Derived SM-2 snapshot. The append-only `ReviewEvent` stream is the source of truth.
public struct SRSState: Codable, Equatable, Sendable {
    public var easiness: Double
    public var intervalDays: Int
    public var repetitions: Int
    /// Study-day due (success: interval-aligned 04:00; failure: next study-day 04:00).
    public var dueAt: Date
    /// Failure-only 10-minute cooldown. `nil` means no gate (success or never reviewed).
    public var relearnGateAt: Date?
    public var lastReviewedAt: Date?
    public var lastQuality: Int?
    public var contentRevision: Int

    public static let initialEasiness: Double = 2.5
    public static let minimumEasiness: Double = 1.3

    public init(
        easiness: Double = Self.initialEasiness,
        intervalDays: Int = 0,
        repetitions: Int = 0,
        dueAt: Date,
        relearnGateAt: Date? = nil,
        lastReviewedAt: Date? = nil,
        lastQuality: Int? = nil,
        contentRevision: Int = 0
    ) {
        self.easiness = easiness
        self.intervalDays = intervalDays
        self.repetitions = repetitions
        self.dueAt = dueAt
        self.relearnGateAt = relearnGateAt
        self.lastReviewedAt = lastReviewedAt
        self.lastQuality = lastQuality
        self.contentRevision = contentRevision
    }

    public static func initial(now: Date, contentRevision: Int = 0) -> SRSState {
        SRSState(dueAt: now, contentRevision: contentRevision)
    }

    /// True when the 10-minute relearn gate has passed (or there is no gate).
    public func isPastRelearnGate(at now: Date) -> Bool {
        guard let relearnGateAt else { return true }
        return now >= relearnGateAt
    }

    /// Daily-queue eligibility: gate passed **and** `dueAt` has arrived (architecture §6.4).
    public func isDue(at now: Date) -> Bool {
        isPastRelearnGate(at: now) && now >= dueAt
    }

    /// Same-day retry after a failure: allowed once the gate opens, even before the next study-day due.
    public func canRelearnSameDay(at now: Date) -> Bool {
        isPastRelearnGate(at: now)
    }
}
