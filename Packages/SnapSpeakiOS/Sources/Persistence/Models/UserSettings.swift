import Foundation
import SwiftData

@Model
public final class UserSettings {
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
        reminderMinute: Int,
        reminderEnabled: Bool,
        dailyGoalItems: Int,
        onboardingCompletedAt: Date?,
        lastKnownStreakDays: Int,
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
}
