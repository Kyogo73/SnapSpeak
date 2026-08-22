import Foundation
import HabitKit
import SRSKit

/// Sendable snapshot of a persisted `LessonAttempt`. `payloadJSON` always travels with
/// `payloadSchemaVersion` so later schema changes can be decoded without guessing.
public struct LessonAttemptDTO: Sendable, Equatable, Identifiable {
    public var id: UUID
    public var courseId: String
    public var lessonId: String
    public var itemId: String
    public var contentRevision: Int
    public var languagePairKey: String
    public var skill: String
    public var createdAt: Date
    public var durationMs: Int
    public var payloadSchemaVersion: Int
    public var payloadJSON: Data

    public init(
        id: UUID,
        courseId: String,
        lessonId: String,
        itemId: String,
        contentRevision: Int,
        languagePairKey: String,
        skill: String,
        createdAt: Date,
        durationMs: Int,
        payloadSchemaVersion: Int,
        payloadJSON: Data
    ) {
        self.id = id
        self.courseId = courseId
        self.lessonId = lessonId
        self.itemId = itemId
        self.contentRevision = contentRevision
        self.languagePairKey = languagePairKey
        self.skill = skill
        self.createdAt = createdAt
        self.durationMs = durationMs
        self.payloadSchemaVersion = payloadSchemaVersion
        self.payloadJSON = payloadJSON
    }
}

/// Append-only write. Same payload pairing rules as `LessonAttemptDTO`.
public struct LessonAttemptWrite: Sendable, Equatable {
    public var id: UUID
    public var courseId: String
    public var lessonId: String
    public var itemId: String
    public var contentRevision: Int
    public var languagePairKey: String
    public var skill: String
    public var createdAt: Date
    public var durationMs: Int
    public var payloadSchemaVersion: Int
    public var payloadJSON: Data

    public init(
        id: UUID = UUID(),
        courseId: String,
        lessonId: String,
        itemId: String,
        contentRevision: Int,
        languagePairKey: String,
        skill: String,
        createdAt: Date,
        durationMs: Int,
        payloadSchemaVersion: Int,
        payloadJSON: Data
    ) {
        self.id = id
        self.courseId = courseId
        self.lessonId = lessonId
        self.itemId = itemId
        self.contentRevision = contentRevision
        self.languagePairKey = languagePairKey
        self.skill = skill
        self.createdAt = createdAt
        self.durationMs = durationMs
        self.payloadSchemaVersion = payloadSchemaVersion
        self.payloadJSON = payloadJSON
    }
}

/// Extra fields stored beside `ReviewEventDTO` so the SwiftData row can be rebuilt.
public struct ReviewEventWrite: Sendable, Equatable {
    public var event: ReviewEventDTO
    public var courseId: String
    public var itemId: String
    public var skill: String
    public var payloadSchemaVersion: Int
    public var payloadJSON: Data

    public init(
        event: ReviewEventDTO,
        courseId: String,
        itemId: String,
        skill: String,
        payloadSchemaVersion: Int = 1,
        payloadJSON: Data = Data("{}".utf8)
    ) {
        self.event = event
        self.courseId = courseId
        self.itemId = itemId
        self.skill = skill
        self.payloadSchemaVersion = payloadSchemaVersion
        self.payloadJSON = payloadJSON
    }
}

public struct SRSCardDTO: Sendable, Equatable {
    public var cardKey: String
    public var sourceLanguage: String
    public var targetLanguage: String
    public var courseId: String
    public var itemId: String
    public var skill: String
    public var contentRevision: Int
    public var inheritSRS: Bool
    public var easiness: Double
    public var intervalDays: Int
    public var repetitions: Int
    public var dueAt: Date
    public var relearnGateAt: Date?
    public var lastReviewedAt: Date?
    public var lastQuality: Int?
    public var foldedThroughRevision: Int64?

    public init(
        cardKey: String,
        sourceLanguage: String,
        targetLanguage: String,
        courseId: String,
        itemId: String,
        skill: String,
        contentRevision: Int,
        inheritSRS: Bool,
        easiness: Double,
        intervalDays: Int,
        repetitions: Int,
        dueAt: Date,
        relearnGateAt: Date? = nil,
        lastReviewedAt: Date?,
        lastQuality: Int?,
        foldedThroughRevision: Int64?
    ) {
        self.cardKey = cardKey
        self.sourceLanguage = sourceLanguage
        self.targetLanguage = targetLanguage
        self.courseId = courseId
        self.itemId = itemId
        self.skill = skill
        self.contentRevision = contentRevision
        self.inheritSRS = inheritSRS
        self.easiness = easiness
        self.intervalDays = intervalDays
        self.repetitions = repetitions
        self.dueAt = dueAt
        self.relearnGateAt = relearnGateAt
        self.lastReviewedAt = lastReviewedAt
        self.lastQuality = lastQuality
        self.foldedThroughRevision = foldedThroughRevision
    }
}

public struct UserSettingsDTO: Sendable, Equatable {
    public var sourceLanguage: String
    public var targetLanguage: String
    public var captionsEnabled: Bool
    public var defaultRate: Float
    public var reminderHour: Int?
    public var reminderMinute: Int
    public var reminderEnabled: Bool
    public var dailyGoalItems: Int
    public var onboardingCompletedAt: Date?
    public var lastKnownStreakDays: Int
    public var habitStreakRecordedDayStart: Date?
    public var habitGoalMetDayStart: Date?
    public var habitBrokenRecordedDayStart: Date?
    public var recoveryDismissedFromStreak: Int
    public var lastOpenedCourseId: String?
    public var lastOpenedLessonId: String?
    public var lastOpenedItemId: String?
    public var lastOpenedMode: String?
    public var fieldRevisionsJSON: Data
    public var deletedAt: Date?

    public init(
        sourceLanguage: String,
        targetLanguage: String,
        captionsEnabled: Bool,
        defaultRate: Float,
        reminderHour: Int?,
        reminderMinute: Int = 0,
        reminderEnabled: Bool = false,
        dailyGoalItems: Int = 10,
        onboardingCompletedAt: Date? = nil,
        lastKnownStreakDays: Int = 0,
        habitStreakRecordedDayStart: Date? = nil,
        habitGoalMetDayStart: Date? = nil,
        habitBrokenRecordedDayStart: Date? = nil,
        recoveryDismissedFromStreak: Int = 0,
        lastOpenedCourseId: String? = nil,
        lastOpenedLessonId: String? = nil,
        lastOpenedItemId: String? = nil,
        lastOpenedMode: String? = nil,
        fieldRevisionsJSON: Data,
        deletedAt: Date?
    ) {
        self.sourceLanguage = sourceLanguage
        self.targetLanguage = targetLanguage
        self.captionsEnabled = captionsEnabled
        self.defaultRate = defaultRate
        self.reminderHour = reminderHour
        self.reminderMinute = reminderMinute
        self.reminderEnabled = reminderEnabled
        self.dailyGoalItems = dailyGoalItems
        self.onboardingCompletedAt = onboardingCompletedAt
        self.lastKnownStreakDays = lastKnownStreakDays
        self.habitStreakRecordedDayStart = habitStreakRecordedDayStart
        self.habitGoalMetDayStart = habitGoalMetDayStart
        self.habitBrokenRecordedDayStart = habitBrokenRecordedDayStart
        self.recoveryDismissedFromStreak = recoveryDismissedFromStreak
        self.lastOpenedCourseId = lastOpenedCourseId
        self.lastOpenedLessonId = lastOpenedLessonId
        self.lastOpenedItemId = lastOpenedItemId
        self.lastOpenedMode = lastOpenedMode
        self.fieldRevisionsJSON = fieldRevisionsJSON
        self.deletedAt = deletedAt
    }

    public var habitMarkers: HabitDayMarkers {
        HabitDayMarkers(
            streakRecordedDayStart: habitStreakRecordedDayStart,
            goalMetDayStart: habitGoalMetDayStart,
            brokenRecordedDayStart: habitBrokenRecordedDayStart
        )
    }

    public static let phase1Default = UserSettingsDTO(
        sourceLanguage: "ja",
        targetLanguage: "en",
        captionsEnabled: true,
        defaultRate: 1.0,
        reminderHour: nil,
        reminderMinute: 0,
        reminderEnabled: false,
        dailyGoalItems: 10,
        onboardingCompletedAt: nil,
        lastKnownStreakDays: 0,
        fieldRevisionsJSON: Data("{}".utf8),
        deletedAt: nil
    )
}

/// Attempt 追記時の習慣イベント（学習日単位の一回性）。
public struct AttemptHabitResult: Sendable, Equatable {
    public var attempt: LessonAttemptDTO
    public var recordStreakDays: Int?
    public var metGoalItems: Int?
    public var dailyGoalItems: Int

    public init(
        attempt: LessonAttemptDTO,
        recordStreakDays: Int?,
        metGoalItems: Int?,
        dailyGoalItems: Int
    ) {
        self.attempt = attempt
        self.recordStreakDays = recordStreakDays
        self.metGoalItems = metGoalItems
        self.dailyGoalItems = dailyGoalItems
    }
}

public struct DownloadedCourseDTO: Sendable, Equatable, Identifiable {
    public var id: String { courseId }
    public var courseId: String
    public var sourceLanguage: String
    public var targetLanguage: String
    public var revision: Int
    public var schemaVersion: Int
    public var releaseId: String
    public var localPath: String
    public var downloadedAt: Date
    public var bytes: Int64
    public var checksumSha256: String

    public init(
        courseId: String,
        sourceLanguage: String,
        targetLanguage: String,
        revision: Int,
        schemaVersion: Int,
        releaseId: String,
        localPath: String,
        downloadedAt: Date,
        bytes: Int64,
        checksumSha256: String
    ) {
        self.courseId = courseId
        self.sourceLanguage = sourceLanguage
        self.targetLanguage = targetLanguage
        self.revision = revision
        self.schemaVersion = schemaVersion
        self.releaseId = releaseId
        self.localPath = localPath
        self.downloadedAt = downloadedAt
        self.bytes = bytes
        self.checksumSha256 = checksumSha256
    }
}

public struct SRSCardFoldRequest: Sendable, Equatable {
    public var cardKey: String
    public var sourceLanguage: String
    public var targetLanguage: String
    public var courseId: String
    public var itemId: String
    public var skill: String
    public var contentRevision: Int
    public var inheritSRS: Bool
    public var now: Date
    public var timeZoneIdentifier: String
    public var dayBoundaryHour: Int

    public init(
        cardKey: String,
        sourceLanguage: String,
        targetLanguage: String,
        courseId: String,
        itemId: String,
        skill: String,
        contentRevision: Int,
        inheritSRS: Bool,
        now: Date,
        timeZoneIdentifier: String,
        dayBoundaryHour: Int = 4
    ) {
        self.cardKey = cardKey
        self.sourceLanguage = sourceLanguage
        self.targetLanguage = targetLanguage
        self.courseId = courseId
        self.itemId = itemId
        self.skill = skill
        self.contentRevision = contentRevision
        self.inheritSRS = inheritSRS
        self.now = now
        self.timeZoneIdentifier = timeZoneIdentifier
        self.dayBoundaryHour = dayBoundaryHour
    }
}
