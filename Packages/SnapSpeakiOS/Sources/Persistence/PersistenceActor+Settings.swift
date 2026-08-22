import Foundation
import SwiftData

extension PersistenceActor {
    public func loadOrCreateSettings() throws -> UserSettingsDTO {
        var descriptor = FetchDescriptor<UserSettings>()
        descriptor.fetchLimit = 1
        if let existing = try modelContext.fetch(descriptor).first {
            return PersistenceMapping.settingsDTO(existing)
        }
        let defaults = UserSettingsDTO.phase1Default
        let model = UserSettings(
            sourceLanguage: defaults.sourceLanguage,
            targetLanguage: defaults.targetLanguage,
            captionsEnabled: defaults.captionsEnabled,
            defaultRate: defaults.defaultRate,
            reminderHour: defaults.reminderHour,
            reminderMinute: defaults.reminderMinute,
            reminderEnabled: defaults.reminderEnabled,
            dailyGoalItems: defaults.dailyGoalItems,
            onboardingCompletedAt: defaults.onboardingCompletedAt,
            lastKnownStreakDays: defaults.lastKnownStreakDays,
            habitStreakRecordedDayStart: defaults.habitStreakRecordedDayStart,
            habitGoalMetDayStart: defaults.habitGoalMetDayStart,
            habitBrokenRecordedDayStart: defaults.habitBrokenRecordedDayStart,
            recoveryDismissedFromStreak: defaults.recoveryDismissedFromStreak,
            lastOpenedCourseId: defaults.lastOpenedCourseId,
            lastOpenedLessonId: defaults.lastOpenedLessonId,
            lastOpenedItemId: defaults.lastOpenedItemId,
            lastOpenedMode: defaults.lastOpenedMode,
            fieldRevisionsJSON: defaults.fieldRevisionsJSON,
            deletedAt: defaults.deletedAt
        )
        modelContext.insert(model)
        try saveOrRollback()
        return PersistenceMapping.settingsDTO(model)
    }

    public func saveSettings(_ dto: UserSettingsDTO) throws -> UserSettingsDTO {
        var descriptor = FetchDescriptor<UserSettings>()
        descriptor.fetchLimit = 1
        let model: UserSettings
        if let existing = try modelContext.fetch(descriptor).first {
            model = existing
        } else {
            model = UserSettings(
                sourceLanguage: dto.sourceLanguage,
                targetLanguage: dto.targetLanguage,
                captionsEnabled: dto.captionsEnabled,
                defaultRate: dto.defaultRate,
                reminderHour: dto.reminderHour,
                reminderMinute: dto.reminderMinute,
                reminderEnabled: dto.reminderEnabled,
                dailyGoalItems: dto.dailyGoalItems,
                onboardingCompletedAt: dto.onboardingCompletedAt,
                lastKnownStreakDays: dto.lastKnownStreakDays,
                habitStreakRecordedDayStart: dto.habitStreakRecordedDayStart,
                habitGoalMetDayStart: dto.habitGoalMetDayStart,
                habitBrokenRecordedDayStart: dto.habitBrokenRecordedDayStart,
                recoveryDismissedFromStreak: dto.recoveryDismissedFromStreak,
                lastOpenedCourseId: dto.lastOpenedCourseId,
                lastOpenedLessonId: dto.lastOpenedLessonId,
                lastOpenedItemId: dto.lastOpenedItemId,
                lastOpenedMode: dto.lastOpenedMode,
                fieldRevisionsJSON: dto.fieldRevisionsJSON,
                deletedAt: dto.deletedAt
            )
            modelContext.insert(model)
        }
        model.sourceLanguage = dto.sourceLanguage
        model.targetLanguage = dto.targetLanguage
        model.captionsEnabled = dto.captionsEnabled
        model.defaultRate = dto.defaultRate
        model.reminderHour = dto.reminderHour
        model.reminderMinute = dto.reminderMinute
        model.reminderEnabled = dto.reminderEnabled
        model.dailyGoalItems = dto.dailyGoalItems
        model.onboardingCompletedAt = dto.onboardingCompletedAt
        model.lastKnownStreakDays = dto.lastKnownStreakDays
        model.habitStreakRecordedDayStart = dto.habitStreakRecordedDayStart
        model.habitGoalMetDayStart = dto.habitGoalMetDayStart
        model.habitBrokenRecordedDayStart = dto.habitBrokenRecordedDayStart
        model.recoveryDismissedFromStreak = dto.recoveryDismissedFromStreak
        model.lastOpenedCourseId = dto.lastOpenedCourseId
        model.lastOpenedLessonId = dto.lastOpenedLessonId
        model.lastOpenedItemId = dto.lastOpenedItemId
        model.lastOpenedMode = dto.lastOpenedMode
        model.fieldRevisionsJSON = dto.fieldRevisionsJSON
        model.deletedAt = dto.deletedAt
        try saveOrRollback()
        return PersistenceMapping.settingsDTO(model)
    }

    /// 設定モデル本体を返す（習慣系の部分更新用。extension からも使うため internal）。
    func requireSettings() throws -> UserSettings {
        _ = try loadOrCreateSettings()
        var descriptor = FetchDescriptor<UserSettings>()
        descriptor.fetchLimit = 1
        guard let model = try modelContext.fetch(descriptor).first else {
            throw PersistenceError.missingSettings
        }
        return model
    }
}
