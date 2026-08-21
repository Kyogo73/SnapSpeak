import Foundation

/// Derived SM-2 snapshot. The append-only `ReviewEvent` stream is the source of truth.
public struct SRSState: Codable, Equatable, Sendable {
    public var easiness: Double
    public var intervalDays: Int
    public var repetitions: Int
    public var dueAt: Date
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
        lastReviewedAt: Date? = nil,
        lastQuality: Int? = nil,
        contentRevision: Int = 0
    ) {
        self.easiness = easiness
        self.intervalDays = intervalDays
        self.repetitions = repetitions
        self.dueAt = dueAt
        self.lastReviewedAt = lastReviewedAt
        self.lastQuality = lastQuality
        self.contentRevision = contentRevision
    }

    public static func initial(now: Date, contentRevision: Int = 0) -> SRSState {
        SRSState(dueAt: now, contentRevision: contentRevision)
    }
}
