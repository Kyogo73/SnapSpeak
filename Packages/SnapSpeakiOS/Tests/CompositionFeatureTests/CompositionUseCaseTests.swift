import Analytics
import AudioEngine
import CompositionFeature
import CompositionKit
import ContentCore
import ContentKit
import Foundation
import LanguageKit
import Persistence
import SpeechKit
import SRSKit
import Testing

@Suite("CompositionUseCase")
struct CompositionUseCaseTests {
    @Test("CompositionAttemptPayload の encode/decode roundtrip")
    func payloadRoundTrip() throws {
        let original = CompositionAttemptPayload(
            payloadSchemaVersion: 1,
            result: "unscored",
            usedHint: true,
            latencyMs: 1_200
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(CompositionAttemptPayload.self, from: data)
        #expect(decoded == original)
        #expect(CompositionAttemptPayload.resultLabel(for: .unscored) == "unscored")
        #expect(CompositionAttemptPayload.resultLabel(for: .fail) == "fail")
        #expect(CompositionAttemptPayload.resultLabel(for: .pass(kind: .normalizedMatch)) == "pass")
        #expect(CompositionGrade.unscored.shouldAppendReviewEvent == false)
    }

    @Test("空 ASR は unscored・Attempt 追記・ReviewEvent 0 件")
    func emptyTranscriptPersistsUnscoredWithoutReviewEvent() async throws {
        let outcome = try await finish(
            speech: FakeSpeech(result: .success([])),
            usedHint: false
        )
        #expect(outcome.grade == .unscored)
        #expect(outcome.persisted)
        #expect(outcome.quality == nil)
    }

    @Test("認識 throw は unscored・Attempt 追記・ReviewEvent 0 件")
    func recognitionThrowPersistsUnscoredWithoutReviewEvent() async throws {
        let outcome = try await finish(
            speech: FakeSpeech(result: .failure(SpeechClientError.recognitionFailed)),
            usedHint: true
        )
        #expect(outcome.grade == .unscored)
        #expect(outcome.persisted)
    }

    private func finish(
        speech: FakeSpeech,
        usedHint: Bool
    ) async throws -> CompositionOutcome {
        let fixture = try CompositionFixture()
        let useCase = LiveCompositionUseCase(
            audio: AudioEngineActor(analytics: NoopAnalytics()),
            speech: speech,
            persistence: fixture.persistence,
            analytics: NoopAnalytics(),
            recordingsDirectory: fixture.recordings,
            permissions: AuthorizedPermissions()
        )
        let dummy = fixture.recordings.appendingPathComponent("dummy.caf")
        try Data().write(to: dummy)
        let outcome = try await useCase.finishRecording(
            item: fixture.item,
            stored: fixture.stored,
            lessonId: fixture.lessonId,
            recordingURL: dummy,
            latencyMs: 900,
            usedHint: usedHint
        )
        let attempt = try await fixture.persistence.latestAttempt()
        #expect(attempt != nil)
        #expect(attempt?.skill == Skill.composition.rawValue)
        let payload = try JSONDecoder().decode(
            CompositionAttemptPayload.self,
            from: attempt?.payloadJSON ?? Data()
        )
        #expect(payload.result == "unscored")
        #expect(payload.payloadSchemaVersion == 1)
        #expect(payload.usedHint == usedHint)
        #expect(payload.latencyMs == 900)
        let cardKey = CardKey(
            pair: fixture.stored.course.languagePair,
            courseId: fixture.stored.course.id,
            itemId: fixture.item.id,
            skill: .composition
        ).raw
        #expect(try await fixture.persistence.reviewEvents(forCardKey: cardKey).isEmpty)
        return outcome
    }
}

private struct CompositionFixture {
    let persistence: PersistenceActor
    let stored: StoredCourse
    let item: ItemV1
    let lessonId: String
    let recordings: URL

    init() throws {
        let container = try PersistenceActor.makeContainer(inMemory: true)
        persistence = PersistenceActor(modelContainer: container)
        let pair = LanguagePair(
            sourceLanguage: try BCP47Language("ja"),
            targetLanguage: try BCP47Language("en")
        )
        item = try ItemV1(
            id: "item_comp_1",
            kind: .composition,
            sentencePair: SentencePairV1(l1: "こんにちは", acceptable: ["Hello"])
        )
        lessonId = "lesson_comp"
        let course = CourseV1(
            schemaVersion: 1,
            id: "course_comp",
            languagePair: pair,
            title: ["ja": "comp"],
            units: [
                UnitV1(
                    id: "unit_1",
                    title: ["ja": "u"],
                    lessons: [LessonV1(id: lessonId, mode: .composition, items: [item])]
                ),
            ]
        )
        stored = StoredCourse(
            course: course,
            origin: .seed,
            directory: URL(fileURLWithPath: "/tmp"),
            revision: 1,
            releaseId: nil
        )
        recordings = FileManager.default.temporaryDirectory
            .appendingPathComponent("composition-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: recordings, withIntermediateDirectories: true)
    }
}

private struct FakeSpeech: SpeechRecognizing {
    enum Result {
        case success([SpeechTranscriptSegment])
        case failure(Error)
    }

    var result: Result

    func recognize(
        url: URL,
        locale: Locale,
        timeout: TimeInterval
    ) async throws -> [SpeechTranscriptSegment] {
        _ = url
        _ = locale
        _ = timeout
        switch result {
        case let .success(segments):
            return segments
        case let .failure(error):
            throw error
        }
    }
}

private struct AuthorizedPermissions: RecordingPermissionClient {
    func microphoneStatus() -> MediaPermission { .authorized }
    func requestMicrophone() async -> MediaPermission { .authorized }
    func speechStatus() -> MediaPermission { .authorized }
    func requestSpeech() async -> MediaPermission { .authorized }
}

private struct NoopAnalytics: AnalyticsClient {
    func track(_ event: AnalyticsEvent) {}
}
