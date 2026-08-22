import Analytics
import DriveKit
import Foundation
import Persistence
import SRSKit

/// ドライブ完了は `appendAttemptEvaluatingHabit` のみ。ReviewEvent / foldSRSCard は呼ばない。
public struct DriveAttemptRecorder: Sendable {
    public var persistence: PersistenceActor
    public var analytics: any AnalyticsClient

    public init(persistence: PersistenceActor, analytics: any AnalyticsClient) {
        self.persistence = persistence
        self.analytics = analytics
    }

    public func record(
        item: DriveItem,
        lookup: DrivePlanResolver.Lookup,
        passIndex: Int,
        usedTTSFallback: Bool,
        elapsedMs: Int,
        settings: DriveScriptSettings
    ) async throws -> AttemptHabitResult {
        let payload = try makePayload(
            item: item,
            passIndex: passIndex,
            usedTTSFallback: usedTTSFallback,
            settings: settings
        )
        let schemaVersion = item.skill == .shadowing
            ? DriveAttemptPayload.shadowingSchemaVersion
            : DriveAttemptPayload.compositionSchemaVersion
        let habit = try await persistence.appendAttemptEvaluatingHabit(
            LessonAttemptWrite(
                courseId: item.courseId,
                lessonId: lookup.lessonId,
                itemId: item.itemId,
                contentRevision: lookup.contentRevision,
                languagePairKey: lookup.languagePairKey,
                skill: item.skill.rawValue,
                createdAt: Date(),
                durationMs: elapsedMs,
                payloadSchemaVersion: schemaVersion,
                payloadJSON: payload
            )
        )
        trackHabit(habit)
        return habit
    }

    /// LiveShadowingUseCase.trackHabit と同型。Feature 間 import を避けるため意図的に重複。
    private func trackHabit(_ result: AttemptHabitResult) {
        if let days = result.recordStreakDays {
            analytics.track(.streakDayRecorded(streakBand: Quantization.streakBand(days: days)))
        }
        if result.metGoalItems != nil {
            analytics.track(.goalMet(goalItems: result.dailyGoalItems))
        }
    }

    private func makePayload(
        item: DriveItem,
        passIndex: Int,
        usedTTSFallback: Bool,
        settings: DriveScriptSettings
    ) throws -> Data {
        let answer = settings.timing.answerMs(audioDurationMs: item.audioDurationMs, l2Text: item.l2Text)
        let payload: DriveAttemptPayload
        switch item.skill {
        case .shadowing:
            payload = DriveAttemptPayload(
                payloadSchemaVersion: DriveAttemptPayload.shadowingSchemaVersion,
                passIndex: passIndex,
                usedTTSFallback: usedTTSFallback,
                repeats: settings.shadowingRepeats
            )
        case .composition:
            payload = DriveAttemptPayload(
                payloadSchemaVersion: DriveAttemptPayload.compositionSchemaVersion,
                passIndex: passIndex,
                usedTTSFallback: usedTTSFallback,
                speakPauseMs: settings.timing.speakPauseMs(
                    answerMs: answer,
                    pauseMultiplier: settings.pauseMultiplier
                )
            )
        }
        return try JSONEncoder().encode(payload)
    }
}
