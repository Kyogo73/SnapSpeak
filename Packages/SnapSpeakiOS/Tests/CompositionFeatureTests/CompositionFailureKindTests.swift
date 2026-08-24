import CompositionFeature
import CompositionKit
import ContentCore
import ContentKit
import Foundation
import LanguageKit
import Testing

@Suite("CompositionSessionViewModel failures")
@MainActor
struct CompositionFailureKindTests {
    @Test("course 欠落は .failed(.load)")
    func missingCourseMapsToLoadFailure() async throws {
        let (store, root) = try Self.emptyStore()
        defer { try? FileManager.default.removeItem(at: root) }
        let useCase = FakeCompositionUseCase()
        let viewModel = Self.makeViewModel(useCase: useCase, store: store)

        await viewModel.load()

        #expect(viewModel.phase == .failed(.load))
    }

    @Test("item 欠落は .failed(.load)")
    func missingItemMapsToLoadFailure() async throws {
        let (store, root) = try Self.makeStore(course: Self.compositionCourse())
        defer { try? FileManager.default.removeItem(at: root) }
        let useCase = FakeCompositionUseCase()
        let viewModel = Self.makeViewModel(
            itemId: "missing-item",
            useCase: useCase,
            store: store
        )

        await viewModel.load()

        #expect(viewModel.phase == .failed(.load))
    }

    @Test("startSpeaking の microphoneDenied 以外は .failed(.playback)")
    func startSpeakingMapsNonMicErrorToPlaybackFailure() async throws {
        let (store, root) = try Self.makeStore(course: Self.compositionCourse())
        defer { try? FileManager.default.removeItem(at: root) }
        let useCase = FakeCompositionUseCase()
        useCase.startRecordingError = FakeLessonError.boom
        let viewModel = Self.makeViewModel(useCase: useCase, store: store)

        await viewModel.load()
        await viewModel.startSpeaking()

        #expect(viewModel.phase == .failed(.playback))
    }

    @Test("startSpeaking の microphoneDenied は .prompt を維持する")
    func startSpeakingKeepsMicrophoneDeniedOnPrompt() async throws {
        let (store, root) = try Self.makeStore(course: Self.compositionCourse())
        defer { try? FileManager.default.removeItem(at: root) }
        let useCase = FakeCompositionUseCase()
        useCase.startRecordingError = CompositionUseCaseError.microphoneDenied
        let viewModel = Self.makeViewModel(useCase: useCase, store: store)

        await viewModel.load()
        await viewModel.startSpeaking()

        #expect(viewModel.phase == .prompt)
        #expect(viewModel.microphoneDenied)
    }

    @Test("submitTyped の失敗は .failed(.scoring)")
    func submitTypedMapsToScoringFailure() async throws {
        let (store, root) = try Self.makeStore(course: Self.compositionCourse())
        defer { try? FileManager.default.removeItem(at: root) }
        let useCase = FakeCompositionUseCase()
        useCase.gradeTypedError = FakeLessonError.boom
        let viewModel = Self.makeViewModel(useCase: useCase, store: store)

        await viewModel.load()
        await viewModel.submitTyped()

        #expect(viewModel.phase == .failed(.scoring))
        #expect(useCase.gradeTypedCount == 1)
    }

    @Test("finishSpeaking の失敗は .failed(.scoring)")
    func finishSpeakingMapsToScoringFailure() async throws {
        let (store, root) = try Self.makeStore(course: Self.compositionCourse())
        defer { try? FileManager.default.removeItem(at: root) }
        let useCase = FakeCompositionUseCase()
        useCase.finishRecordingError = FakeLessonError.boom
        let viewModel = Self.makeViewModel(useCase: useCase, store: store)

        await viewModel.load()
        await viewModel.startSpeaking()
        await viewModel.finishSpeaking()

        #expect(viewModel.phase == .failed(.scoring))
        #expect(useCase.finishRecordingCount == 1)
    }

    @Test("採点失敗の retry は submitTyped / finishSpeaking を再実行せず .prompt に戻す")
    func scoringRetryReturnsPromptWithoutRescoring() async throws {
        let (store, root) = try Self.makeStore(course: Self.compositionCourse())
        defer { try? FileManager.default.removeItem(at: root) }
        let useCase = FakeCompositionUseCase()
        useCase.gradeTypedError = FakeLessonError.boom
        let viewModel = Self.makeViewModel(useCase: useCase, store: store)
        viewModel.typedText = "Hello"

        await viewModel.load()
        await viewModel.submitTyped()
        #expect(viewModel.phase == .failed(.scoring))
        #expect(useCase.gradeTypedCount == 1)
        #expect(useCase.finishRecordingCount == 0)

        viewModel.retryAfterScoringFailure()

        #expect(viewModel.phase == .prompt)
        #expect(viewModel.outcome == nil)
        #expect(viewModel.typedText == "Hello")
        #expect(useCase.gradeTypedCount == 1)
        #expect(useCase.finishRecordingCount == 0)
    }

    @Test("spoken 採点失敗の retry も finishSpeaking を再実行しない")
    func spokenScoringRetryDoesNotCallFinishSpeakingAgain() async throws {
        let (store, root) = try Self.makeStore(course: Self.compositionCourse())
        defer { try? FileManager.default.removeItem(at: root) }
        let useCase = FakeCompositionUseCase()
        useCase.finishRecordingError = FakeLessonError.boom
        let viewModel = Self.makeViewModel(useCase: useCase, store: store)

        await viewModel.load()
        await viewModel.startSpeaking()
        await viewModel.finishSpeaking()
        #expect(viewModel.phase == .failed(.scoring))
        #expect(useCase.finishRecordingCount == 1)

        viewModel.retryAfterScoringFailure()

        #expect(viewModel.phase == .prompt)
        #expect(useCase.finishRecordingCount == 1)
        #expect(useCase.gradeTypedCount == 0)
    }

    private static func makeViewModel(
        courseId: String = "course_c",
        lessonId: String = "lesson_c",
        itemId: String = "item_c",
        useCase: FakeCompositionUseCase,
        store: CourseStore
    ) -> CompositionSessionViewModel {
        CompositionSessionViewModel(
            courseId: courseId,
            lessonId: lessonId,
            itemId: itemId,
            useCase: useCase,
            courseStore: store
        )
    }

    private static func compositionCourse(
        courseId: String = "course_c",
        lessonId: String = "lesson_c",
        itemId: String = "item_c",
        acceptable: [String] = ["Hello there"]
    ) throws -> CourseV1 {
        let item = try ItemV1(
            id: itemId,
            kind: .composition,
            sentencePair: SentencePairV1(l1: "こんにちは", acceptable: acceptable)
        )
        return CourseV1(
            schemaVersion: 1,
            id: courseId,
            languagePair: LanguagePair(
                sourceLanguage: try BCP47Language("ja"),
                targetLanguage: try BCP47Language("en")
            ),
            title: ["ja": "c"],
            units: [
                UnitV1(
                    id: "unit_c",
                    title: ["ja": "u"],
                    lessons: [LessonV1(id: lessonId, mode: .composition, items: [item])]
                ),
            ]
        )
    }

    private static func emptyStore() throws -> (CourseStore, URL) {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("composition-empty-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return (CourseStore(seed: SeedInstaller(bundle: .main), downloadsRoot: root), root)
    }

    private static func makeStore(course: CourseV1) throws -> (CourseStore, URL) {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("composition-store-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let directory = root
            .appendingPathComponent(course.id, isDirectory: true)
            .appendingPathComponent("1", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try JSONEncoder().encode(course).write(to: directory.appendingPathComponent("index.json"))
        return (CourseStore(seed: SeedInstaller(bundle: .main), downloadsRoot: root), root)
    }
}

private enum FakeLessonError: Error {
    case boom
}

private final class FakeCompositionUseCase: CompositionUseCase, @unchecked Sendable {
    var startRecordingError: Error?
    var gradeTypedError: Error?
    var finishRecordingError: Error?
    var startRecordingURL = URL(fileURLWithPath: "/tmp/composition-test.caf")
    private(set) var gradeTypedCount = 0
    private(set) var finishRecordingCount = 0

    func gradeTyped(
        item: ItemV1,
        stored: StoredCourse,
        lessonId: String,
        input: String,
        latencyMs: Int,
        usedHint: Bool
    ) async throws -> CompositionOutcome {
        _ = item
        _ = stored
        _ = lessonId
        _ = input
        _ = latencyMs
        _ = usedHint
        gradeTypedCount += 1
        if let gradeTypedError {
            throw gradeTypedError
        }
        return CompositionOutcome(grade: .fail, quality: nil)
    }

    func startRecording(item: ItemV1) async throws -> URL {
        _ = item
        if let startRecordingError {
            throw startRecordingError
        }
        return startRecordingURL
    }

    func finishRecording(
        item: ItemV1,
        stored: StoredCourse,
        lessonId: String,
        recordingURL: URL,
        latencyMs: Int,
        usedHint: Bool
    ) async throws -> CompositionOutcome {
        _ = item
        _ = stored
        _ = lessonId
        _ = recordingURL
        _ = latencyMs
        _ = usedHint
        finishRecordingCount += 1
        if let finishRecordingError {
            throw finishRecordingError
        }
        return CompositionOutcome(grade: .fail, quality: nil)
    }
}
