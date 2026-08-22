import Foundation
import SRSKit

enum PersistenceMapping {
    static func attemptDTO(_ model: LessonAttempt) -> LessonAttemptDTO {
        LessonAttemptDTO(
            id: model.id,
            courseId: model.courseId,
            lessonId: model.lessonId,
            itemId: model.itemId,
            contentRevision: model.contentRevision,
            languagePairKey: model.languagePairKey,
            skill: model.skill,
            createdAt: model.createdAt,
            durationMs: model.durationMs,
            payloadSchemaVersion: model.payloadSchemaVersion,
            payloadJSON: model.payloadJSON
        )
    }

    static func reviewDTO(_ model: ReviewEvent) -> ReviewEventDTO {
        ReviewEventDTO(
            id: model.id,
            cardKey: model.cardKey,
            quality: model.quality,
            reviewedAt: model.reviewedAt,
            clientSeq: model.clientSeq,
            serverRevision: model.serverRevision,
            contentRevision: model.contentRevision
        )
    }

    static func cardDTO(_ model: SRSCard) -> SRSCardDTO {
        SRSCardDTO(
            cardKey: model.cardKey,
            sourceLanguage: model.sourceLanguage,
            targetLanguage: model.targetLanguage,
            courseId: model.courseId,
            itemId: model.itemId,
            skill: model.skill,
            contentRevision: model.contentRevision,
            inheritSRS: model.inheritSRS,
            easiness: model.easiness,
            intervalDays: model.intervalDays,
            repetitions: model.repetitions,
            dueAt: model.dueAt,
            relearnGateAt: model.relearnGateAt,
            lastReviewedAt: model.lastReviewedAt,
            lastQuality: model.lastQuality,
            foldedThroughRevision: model.foldedThroughRevision
        )
    }

    static func settingsDTO(_ model: UserSettings) -> UserSettingsDTO {
        UserSettingsDTO(
            sourceLanguage: model.sourceLanguage,
            targetLanguage: model.targetLanguage,
            captionsEnabled: model.captionsEnabled,
            defaultRate: model.defaultRate,
            reminderHour: model.reminderHour,
            reminderMinute: model.reminderMinute,
            reminderEnabled: model.reminderEnabled,
            dailyGoalItems: model.dailyGoalItems,
            onboardingCompletedAt: model.onboardingCompletedAt,
            lastKnownStreakDays: model.lastKnownStreakDays,
            habitStreakRecordedDayStart: model.habitStreakRecordedDayStart,
            habitGoalMetDayStart: model.habitGoalMetDayStart,
            habitBrokenRecordedDayStart: model.habitBrokenRecordedDayStart,
            recoveryDismissedFromStreak: model.recoveryDismissedFromStreak,
            lastOpenedCourseId: model.lastOpenedCourseId,
            lastOpenedLessonId: model.lastOpenedLessonId,
            lastOpenedItemId: model.lastOpenedItemId,
            lastOpenedMode: model.lastOpenedMode,
            fieldRevisionsJSON: model.fieldRevisionsJSON,
            deletedAt: model.deletedAt
        )
    }

    static func downloadedDTO(_ model: DownloadedCourse) -> DownloadedCourseDTO {
        DownloadedCourseDTO(
            courseId: model.courseId,
            sourceLanguage: model.sourceLanguage,
            targetLanguage: model.targetLanguage,
            revision: model.revision,
            schemaVersion: model.schemaVersion,
            releaseId: model.releaseId,
            localPath: model.localPath,
            downloadedAt: model.downloadedAt,
            bytes: model.bytes,
            checksumSha256: model.checksumSha256
        )
    }
}
