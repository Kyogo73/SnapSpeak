import Analytics
import AudioEngine
import CompositionKit
import ContentCore
import ContentKit
import Foundation
import LanguageKit
import Persistence
import SpeechKit
import SRSKit

public struct CompositionOutcome: Sendable, Equatable {
    public var grade: CompositionGrade
    public var quality: ReviewQuality?
    public var persisted: Bool

    public init(grade: CompositionGrade, quality: ReviewQuality?, persisted: Bool = false) {
        self.grade = grade
        self.quality = quality
        self.persisted = persisted
    }
}

public protocol CompositionUseCase: Sendable {
    func gradeTyped(
        item: ItemV1,
        stored: StoredCourse,
        lessonId: String,
        input: String,
        latencyMs: Int,
        usedHint: Bool
    ) async throws -> CompositionOutcome

    func startRecording(item: ItemV1) async throws -> URL
    func finishRecording(
        item: ItemV1,
        stored: StoredCourse,
        lessonId: String,
        recordingURL: URL,
        latencyMs: Int,
        usedHint: Bool
    ) async throws -> CompositionOutcome
}

public struct LiveCompositionUseCase: CompositionUseCase {
    public var audio: AudioEngineActor
    public var speech: any SpeechRecognizing
    public var persistence: PersistenceActor
    public var analytics: any AnalyticsClient
    public var recordingsDirectory: URL
    public var localeResolver: any SpeechLocaleResolver
    public var permissions: any RecordingPermissionClient

    public init(
        audio: AudioEngineActor,
        speech: any SpeechRecognizing,
        persistence: PersistenceActor,
        analytics: any AnalyticsClient,
        recordingsDirectory: URL,
        localeResolver: any SpeechLocaleResolver = StaticSpeechLocaleResolver(),
        permissions: any RecordingPermissionClient = LiveRecordingPermissionClient()
    ) {
        self.audio = audio
        self.speech = speech
        self.persistence = persistence
        self.analytics = analytics
        self.recordingsDirectory = recordingsDirectory
        self.localeResolver = localeResolver
        self.permissions = permissions
    }

    public func gradeTyped(
        item: ItemV1,
        stored: StoredCourse,
        lessonId: String,
        input: String,
        latencyMs: Int,
        usedHint: Bool
    ) async throws -> CompositionOutcome {
        analytics.track(
            .lessonStarted(languagePair: stored.course.languagePair.pairKey, lessonId: lessonId)
        )
        var outcome = grade(input: input, item: item, latencyMs: latencyMs, usedHint: usedHint, confidence: nil)
        try await persist(
            outcome: outcome,
            item: item,
            stored: stored,
            lessonId: lessonId,
            latencyMs: latencyMs,
            usedHint: usedHint
        )
        outcome.persisted = true
        return outcome
    }

    public func startRecording(item: ItemV1) async throws -> URL {
        let access = await RecordingPermissionCoordinator.prepare(client: permissions)
        guard access.canRecord else {
            throw CompositionUseCaseError.microphoneDenied
        }
        try FileManager.default.createDirectory(
            at: recordingsDirectory,
            withIntermediateDirectories: true
        )
        let url = recordingsDirectory.appendingPathComponent("\(item.id)-\(UUID().uuidString).caf")
        try await audio.startRecordOnly(recordingURL: url)
        return url
    }

    public func finishRecording(
        item: ItemV1,
        stored: StoredCourse,
        lessonId: String,
        recordingURL: URL,
        latencyMs: Int,
        usedHint: Bool
    ) async throws -> CompositionOutcome {
        _ = await audio.stop()
        let locale = localeResolver.speechLocale(
            for: stored.course.languagePair.targetLanguage,
            regionPreference: nil
        ) ?? Locale(identifier: "en-US")
        let availability = await SpeechAvailability.inspect(locale: locale)
        let canTranscribe = availability.isOnDeviceReady && permissions.speechStatus() == .authorized
        guard canTranscribe else {
            return try await persistUnscored(
                item: item,
                stored: stored,
                lessonId: lessonId,
                latencyMs: latencyMs,
                usedHint: usedHint
            )
        }
        do {
            let segments = try await speech.recognize(url: recordingURL, locale: locale, timeout: 20)
            let hypothesis = segments.map(\.text).joined(separator: " ")
            // 空の認識結果は「不一致」ではなく認識失敗（未採点）。fail の ReviewEvent を書かない。
            guard !hypothesis.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                return try await persistUnscored(
                    item: item,
                    stored: stored,
                    lessonId: lessonId,
                    latencyMs: latencyMs,
                    usedHint: usedHint
                )
            }
            let mean = segments.isEmpty
                ? nil
                : segments.map(\.confidence).reduce(0, +) / Double(segments.count)
            var outcome = grade(
                input: hypothesis,
                item: item,
                latencyMs: latencyMs,
                usedHint: usedHint,
                confidence: mean
            )
            try await persist(
                outcome: outcome,
                item: item,
                stored: stored,
                lessonId: lessonId,
                latencyMs: latencyMs,
                usedHint: usedHint
            )
            outcome.persisted = true
            return outcome
        } catch {
            return try await persistUnscored(
                item: item,
                stored: stored,
                lessonId: lessonId,
                latencyMs: latencyMs,
                usedHint: usedHint
            )
        }
    }

    private func grade(
        input: String,
        item: ItemV1,
        latencyMs: Int,
        usedHint: Bool,
        confidence: Double?
    ) -> CompositionOutcome {
        let acceptable = item.sentencePair?.acceptable ?? []
        let language = BCP47Language.english
        let result = CompositionGrader().grade(input: input, acceptable: acceptable, language: language)
        let passed: Bool
        switch result {
        case .pass: passed = true
        case .fail, .unscored: passed = false
        }
        let tokens = input.split { $0.isWhitespace }.count
        let quality = SRSEngine().qualityForComposition(
            pass: passed,
            latencyMs: latencyMs,
            usedHint: usedHint,
            confidence: confidence,
            tokenCount: tokens,
            skipped: input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
            language: language
        )
        return CompositionOutcome(grade: result, quality: quality)
    }

    private func persist(
        outcome: CompositionOutcome,
        item: ItemV1,
        stored: StoredCourse,
        lessonId: String,
        latencyMs: Int,
        usedHint: Bool
    ) async throws {
        let payload = try JSONEncoder().encode(
            CompositionAttemptPayload(
                payloadSchemaVersion: 1,
                result: CompositionAttemptPayload.resultLabel(for: outcome.grade),
                usedHint: usedHint,
                latencyMs: latencyMs
            )
        )
        let habit = try await persistence.appendAttemptEvaluatingHabit(
            LessonAttemptWrite(
                courseId: stored.course.id,
                lessonId: lessonId,
                itemId: item.id,
                contentRevision: stored.revision,
                languagePairKey: stored.course.languagePair.pairKey,
                skill: Skill.composition.rawValue,
                createdAt: Date(),
                durationMs: latencyMs,
                payloadSchemaVersion: 1,
                payloadJSON: payload
            )
        )
        trackHabit(habit)
        if let quality = outcome.quality, outcome.grade.shouldAppendReviewEvent {
            let seq = try await persistence.nextClientSeq()
            let cardKey = CardKey(
                pair: stored.course.languagePair,
                courseId: stored.course.id,
                itemId: item.id,
                skill: .composition
            ).raw
            let event = ReviewEventDTO(
                id: UUID(),
                cardKey: cardKey,
                quality: quality.rawValue,
                reviewedAt: Date(),
                clientSeq: seq,
                serverRevision: nil,
                contentRevision: stored.revision
            )
            _ = try await persistence.appendReviewEvent(
                ReviewEventWrite(
                    event: event,
                    courseId: stored.course.id,
                    itemId: item.id,
                    skill: Skill.composition.rawValue
                )
            )
            _ = try await persistence.foldSRSCard(
                SRSCardFoldRequest(
                    cardKey: cardKey,
                    sourceLanguage: stored.course.languagePair.sourceLanguage.raw,
                    targetLanguage: stored.course.languagePair.targetLanguage.raw,
                    courseId: stored.course.id,
                    itemId: item.id,
                    skill: Skill.composition.rawValue,
                    contentRevision: stored.revision,
                    inheritSRS: stored.inheritSRS,
                    now: Date(),
                    timeZoneIdentifier: TimeZone.autoupdatingCurrent.identifier
                )
            )
        }
        analytics.track(
            .lessonCompleted(
                languagePair: stored.course.languagePair.pairKey,
                lessonId: lessonId,
                scoreBand: nil,
                durationBand: Quantization.durationBand(ms: latencyMs),
                routeCategory: nil
            )
        )
    }

    private func persistUnscored(
        item: ItemV1,
        stored: StoredCourse,
        lessonId: String,
        latencyMs: Int,
        usedHint: Bool
    ) async throws -> CompositionOutcome {
        var outcome = CompositionOutcome(grade: .unscored, quality: nil)
        try await persist(
            outcome: outcome,
            item: item,
            stored: stored,
            lessonId: lessonId,
            latencyMs: latencyMs,
            usedHint: usedHint
        )
        outcome.persisted = true
        return outcome
    }

    private func trackHabit(_ result: AttemptHabitResult) {
        if let days = result.recordStreakDays {
            analytics.track(.streakDayRecorded(streakBand: Quantization.streakBand(days: days)))
        }
        if result.metGoalItems != nil {
            analytics.track(.goalMet(goalItems: result.dailyGoalItems))
        }
    }
}

public enum CompositionUseCaseError: Error, Sendable {
    case microphoneDenied
}
