import AudioEngine
import ContentCore
import ContentKit
import Foundation
import LanguageKit
@testable import ShadowingFeature
import Testing

@Suite("ShadowingLessonViewModel failures")
@MainActor
struct ShadowingFailureKindTests {
    @Test("course 欠落は .failed(.load)")
    func missingCourseMapsToLoadFailure() async throws {
        let (store, root) = try Self.emptyStore()
        defer { try? FileManager.default.removeItem(at: root) }
        let useCase = FakeShadowingUseCase()
        let viewModel = Self.makeViewModel(useCase: useCase, store: store)

        await viewModel.load()

        #expect(viewModel.phase == .failed(.load))
    }

    @Test("item 欠落は .failed(.load)")
    func missingItemMapsToLoadFailure() async throws {
        let (store, root) = try Self.makeStore(course: Self.shadowingCourse())
        defer { try? FileManager.default.removeItem(at: root) }
        let useCase = FakeShadowingUseCase()
        let viewModel = Self.makeViewModel(
            itemId: "missing-item",
            useCase: useCase,
            store: store
        )

        await viewModel.load()

        #expect(viewModel.phase == .failed(.load))
    }

    @Test("start の microphoneDenied 以外は .failed(.playback)")
    func startMapsNonMicErrorToPlaybackFailure() async throws {
        let (store, root) = try Self.makeStore(course: Self.shadowingCourse())
        defer { try? FileManager.default.removeItem(at: root) }
        let useCase = FakeShadowingUseCase()
        useCase.startPlaybackError = ShadowingUseCaseError.missingAudio
        let viewModel = Self.makeViewModel(useCase: useCase, store: store)

        await viewModel.load()
        await viewModel.start()

        #expect(viewModel.phase == .failed(.playback))
    }

    @Test("start の microphoneDenied は既存フェーズを維持する")
    func startKeepsMicrophoneDenied() async throws {
        let (store, root) = try Self.makeStore(course: Self.shadowingCourse())
        defer { try? FileManager.default.removeItem(at: root) }
        let useCase = FakeShadowingUseCase()
        useCase.startPlaybackError = ShadowingUseCaseError.microphoneDenied
        let viewModel = Self.makeViewModel(useCase: useCase, store: store)

        await viewModel.load()
        await viewModel.start()

        #expect(viewModel.phase == .microphoneDenied)
    }

    @Test("replayPreview の失敗は .failed(.playback)")
    func replayPreviewMapsToPlaybackFailure() async throws {
        let (store, root) = try Self.makeStore(course: Self.shadowingCourse())
        defer { try? FileManager.default.removeItem(at: root) }
        let useCase = FakeShadowingUseCase()
        useCase.previewError = ShadowingUseCaseError.missingAudio
        let viewModel = Self.makeViewModel(useCase: useCase, store: store)

        await viewModel.load()
        await viewModel.replayPreview()

        #expect(viewModel.phase == .failed(.playback))
    }

    @Test("stopAndScore の失敗は .failed(.scoring)")
    func stopAndScoreMapsToScoringFailure() async throws {
        let (store, root) = try Self.makeStore(course: Self.shadowingCourse())
        defer { try? FileManager.default.removeItem(at: root) }
        let useCase = FakeShadowingUseCase()
        useCase.stopAndScoreError = ShadowingUseCaseError.missingAudio
        let viewModel = Self.makeViewModel(useCase: useCase, store: store)

        await viewModel.load()
        await viewModel.stopAndScore()

        #expect(viewModel.phase == .failed(.scoring))
    }

    @Test("採点失敗の retry は stopAndScore を再実行せず asrReady なら .ready")
    func scoringRetryReturnsReadyWithoutRescoring() async throws {
        let (store, root) = try Self.makeStore(course: Self.shadowingCourse())
        defer { try? FileManager.default.removeItem(at: root) }
        let useCase = FakeShadowingUseCase()
        useCase.asrReady = true
        useCase.stopAndScoreError = ShadowingUseCaseError.missingAudio
        let viewModel = Self.makeViewModel(useCase: useCase, store: store)

        await viewModel.load()
        await viewModel.stopAndScore()
        #expect(viewModel.phase == .failed(.scoring))
        #expect(useCase.stopAndScoreCount == 1)

        viewModel.retryAfterScoringFailure()

        #expect(viewModel.phase == .ready)
        #expect(viewModel.score == nil)
        #expect(useCase.stopAndScoreCount == 1)
    }

    @Test("採点失敗の retry は asrReady が false なら .degradedNoASR")
    func scoringRetryReturnsDegradedWhenASRUnavailable() async throws {
        let (store, root) = try Self.makeStore(course: Self.shadowingCourse())
        defer { try? FileManager.default.removeItem(at: root) }
        let useCase = FakeShadowingUseCase()
        useCase.asrReady = false
        useCase.stopAndScoreError = ShadowingUseCaseError.missingAudio
        let viewModel = Self.makeViewModel(useCase: useCase, store: store)

        await viewModel.load()
        #expect(viewModel.phase == .degradedNoASR)
        await viewModel.stopAndScore()
        #expect(viewModel.phase == .failed(.scoring))
        #expect(useCase.stopAndScoreCount == 1)

        viewModel.retryAfterScoringFailure()

        #expect(viewModel.phase == .degradedNoASR)
        #expect(useCase.stopAndScoreCount == 1)
    }

    private static func makeViewModel(
        courseId: String = "course_s",
        lessonId: String = "lesson_s",
        itemId: String = "item_s",
        useCase: FakeShadowingUseCase,
        store: CourseStore
    ) -> ShadowingLessonViewModel {
        ShadowingLessonViewModel(
            courseId: courseId,
            lessonId: lessonId,
            itemId: itemId,
            useCase: useCase,
            courseStore: store,
            captionsEnabled: false,
            defaultRate: 1.0
        )
    }

    private static func shadowingCourse(
        courseId: String = "course_s",
        lessonId: String = "lesson_s",
        itemId: String = "item_s"
    ) throws -> CourseV1 {
        let item = try ItemV1(
            id: itemId,
            kind: .shadowing,
            passage: PassageV1(text: "Hello world", captionSegments: [])
        )
        return CourseV1(
            schemaVersion: 1,
            id: courseId,
            languagePair: LanguagePair(
                sourceLanguage: try BCP47Language("ja"),
                targetLanguage: try BCP47Language("en")
            ),
            title: ["ja": "s"],
            units: [
                UnitV1(
                    id: "unit_s",
                    title: ["ja": "u"],
                    lessons: [LessonV1(id: lessonId, mode: .shadowing, items: [item])]
                ),
            ]
        )
    }

    private static func emptyStore() throws -> (CourseStore, URL) {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("shadowing-empty-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return (CourseStore(seed: SeedInstaller(bundle: .main), downloadsRoot: root), root)
    }

    private static func makeStore(course: CourseV1) throws -> (CourseStore, URL) {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("shadowing-store-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let directory = root
            .appendingPathComponent(course.id, isDirectory: true)
            .appendingPathComponent("1", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try JSONEncoder().encode(course).write(to: directory.appendingPathComponent("index.json"))
        return (CourseStore(seed: SeedInstaller(bundle: .main), downloadsRoot: root), root)
    }
}

private final class FakeShadowingUseCase: ShadowingUseCase, @unchecked Sendable {
    var asrReady = true
    var startPlaybackError: Error?
    var previewError: Error?
    var stopAndScoreError: Error?
    private(set) var stopAndScoreCount = 0

    func prepare(targetLanguage: BCP47Language) async -> ShadowingPreparation {
        _ = targetLanguage
        return ShadowingPreparation(asrReady: asrReady, decision: RoutePolicy.idleDecision)
    }

    func startPlayback(item: ItemV1, stored: StoredCourse, rate: Float) async throws {
        _ = item
        _ = stored
        _ = rate
        if let startPlaybackError {
            throw startPlaybackError
        }
    }

    func startPreviewPlayback(item: ItemV1, stored: StoredCourse, rate: Float) async throws {
        _ = item
        _ = stored
        _ = rate
        if let previewError {
            throw previewError
        }
    }

    func stopAndScore(
        item: ItemV1,
        stored: StoredCourse,
        lessonId: String,
        rate: Float,
        asrReady: Bool
    ) async throws -> ShadowingCompletion {
        _ = item
        _ = stored
        _ = lessonId
        _ = rate
        _ = asrReady
        stopAndScoreCount += 1
        if let stopAndScoreError {
            throw stopAndScoreError
        }
        return ShadowingCompletion(persisted: true, score: nil)
    }
}
