import Analytics
import AudioEngine
import ContentCore
import ContentKit
import Foundation
import LanguageKit
import Persistence
import ScoringKit
import SpeechKit
import SRSKit

public struct ShadowingPreparation: Sendable {
    public var asrReady: Bool
    public var decision: RouteDecision

    public init(asrReady: Bool, decision: RouteDecision) {
        self.asrReady = asrReady
        self.decision = decision
    }
}

public struct ShadowingCompletion: Sendable, Equatable {
    public var persisted: Bool
    public var score: ShadowingScore?

    public init(persisted: Bool, score: ShadowingScore?) {
        self.persisted = persisted
        self.score = score
    }
}

public protocol ShadowingUseCase: Sendable {
    func prepare(targetLanguage: BCP47Language) async -> ShadowingPreparation
    func startPlayback(item: ItemV1, stored: StoredCourse, rate: Float, asrReady: Bool) async throws
    func startPreviewPlayback(item: ItemV1, stored: StoredCourse, rate: Float) async throws
    func stopAndScore(
        item: ItemV1,
        stored: StoredCourse,
        lessonId: String,
        rate: Float,
        asrReady: Bool
    ) async throws -> ShadowingCompletion
}

public struct LiveShadowingUseCase: ShadowingUseCase {
    public var audio: AudioEngineActor
    public var speech: SpeechClient
    public var persistence: PersistenceActor
    public var analytics: any AnalyticsClient
    public var recordingsDirectory: URL
    public var localeResolver: any SpeechLocaleResolver
    public var permissions: any RecordingPermissionClient

    public init(
        audio: AudioEngineActor,
        speech: SpeechClient,
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

    public func prepare(targetLanguage: BCP47Language) async -> ShadowingPreparation {
        let availability = await SpeechAvailability.inspect(
            targetLanguage: targetLanguage,
            resolver: localeResolver
        )
        return ShadowingPreparation(
            asrReady: availability.isOnDeviceReady,
            decision: RoutePolicy.decide()
        )
    }

    public func startPlayback(
        item: ItemV1,
        stored: StoredCourse,
        rate: Float,
        asrReady: Bool
    ) async throws {
        guard let fileURL = audioURL(for: item, stored: stored) else {
            throw ShadowingUseCaseError.missingAudio
        }
        analytics.track(
            .lessonStarted(languagePair: stored.course.languagePair.pairKey, lessonId: item.id)
        )
        _ = asrReady
        let access = await RecordingPermissionCoordinator.prepare(client: permissions)
        guard access.canRecord else {
            try await audio.startPreview(fileURL: fileURL, rate: rate)
            throw ShadowingUseCaseError.microphoneDenied
        }
        let recordingURL = try makeRecordingURL(itemId: item.id)
        try await audio.startShadowingLive(
            fileURL: fileURL,
            recordingURL: recordingURL,
            rate: rate
        )
    }

    public func startPreviewPlayback(item: ItemV1, stored: StoredCourse, rate: Float) async throws {
        guard let fileURL = audioURL(for: item, stored: stored) else {
            throw ShadowingUseCaseError.missingAudio
        }
        try await audio.startPreview(fileURL: fileURL, rate: rate)
    }

    public func stopAndScore(
        item: ItemV1,
        stored: StoredCourse,
        lessonId: String,
        rate: Float,
        asrReady: Bool
    ) async throws -> ShadowingCompletion {
        let session = await audio.stop()
        let canTranscribe = asrReady && permissions.speechStatus() == .authorized
        var score: ShadowingScore?
        if canTranscribe, let recordingURL = session.recordingURL {
            do {
                let locale = localeResolver.speechLocale(
                    for: stored.course.languagePair.targetLanguage,
                    regionPreference: nil
                ) ?? Locale(identifier: "en-US")
                let duration = Double(item.audio?.durationMs ?? 45_000) / 1_000.0
                let segments = try await speech.recognize(
                    url: recordingURL,
                    locale: locale,
                    timeout: duration + 8
                )
                let scorer = ShadowingScorer()
                score = scorer.score(
                    referenceScript: item.passage?.text ?? "",
                    language: stored.course.languagePair.targetLanguage,
                    asrSegments: ScoreMapping.asrSegments(segments),
                    timeline: session.timeline,
                    wordTimings: ScoreMapping.wordTimings(item.passage?.wordTimings),
                    captionSegments: ScoreMapping.captions(item.passage?.captionSegments),
                    audioRoute: session.route,
                    playbackRate: rate,
                    simultaneousPlayAndRecord: session.simultaneousPlayAndRecord
                )
            } catch {
                score = nil
            }
        }

        let payload: Data
        let schemaVersion: Int
        if let score {
            payload = try JSONEncoder().encode(score)
            schemaVersion = score.payloadSchemaVersion
        } else {
            payload = Data("{}".utf8)
            schemaVersion = 1
        }
        let habit = try await persistence.appendAttemptEvaluatingHabit(
            LessonAttemptWrite(
                courseId: stored.course.id,
                lessonId: lessonId,
                itemId: item.id,
                contentRevision: stored.revision,
                languagePairKey: stored.course.languagePair.pairKey,
                skill: Skill.shadowing.rawValue,
                createdAt: Date(),
                durationMs: item.audio?.durationMs ?? 0,
                payloadSchemaVersion: schemaVersion,
                payloadJSON: payload
            )
        )
        trackHabit(habit)

        if let score, let quality = SRSEngine().qualityForShadowing(score: ScoreMapping.snapshot(score)) {
            let seq = try await persistence.nextClientSeq()
            let cardKey = CardKey(
                pair: stored.course.languagePair,
                courseId: stored.course.id,
                itemId: item.id,
                skill: .shadowing
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
                    skill: Skill.shadowing.rawValue
                )
            )
            _ = try await persistence.foldSRSCard(
                SRSCardFoldRequest(
                    cardKey: cardKey,
                    sourceLanguage: stored.course.languagePair.sourceLanguage.raw,
                    targetLanguage: stored.course.languagePair.targetLanguage.raw,
                    courseId: stored.course.id,
                    itemId: item.id,
                    skill: Skill.shadowing.rawValue,
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
                scoreBand: score.map { Quantization.scoreBand($0.scriptMatchRate) },
                durationBand: Quantization.durationBand(ms: item.audio?.durationMs ?? 0),
                routeCategory: session.route.outputPortName
            )
        )
        return ShadowingCompletion(persisted: true, score: score)
    }

    private func trackHabit(_ result: AttemptHabitResult) {
        if let days = result.recordStreakDays {
            analytics.track(.streakDayRecorded(streakBand: Quantization.streakBand(days: days)))
        }
        if result.metGoalItems != nil {
            analytics.track(.goalMet(goalItems: result.dailyGoalItems))
        }
    }

    private func audioURL(for item: ItemV1, stored: StoredCourse) -> URL? {
        guard let relative = item.audio?.relativePath else { return nil }
        return stored.directory.appendingPathComponent(relative)
    }

    private func makeRecordingURL(itemId: String) throws -> URL {
        try FileManager.default.createDirectory(
            at: recordingsDirectory,
            withIntermediateDirectories: true
        )
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        var directory = recordingsDirectory
        try directory.setResourceValues(values)
        return recordingsDirectory.appendingPathComponent("\(itemId)-\(UUID().uuidString).caf")
    }
}

public enum ShadowingUseCaseError: Error, Sendable {
    case missingAudio
    case missingItem
    case missingCourse
    case microphoneDenied
}
