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
        self.fieldRevisionsJSON = fieldRevisionsJSON
        self.deletedAt = deletedAt
    }
}
