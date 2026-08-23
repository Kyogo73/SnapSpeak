import Foundation
import HabitKit

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
