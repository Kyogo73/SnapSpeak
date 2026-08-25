import CompositionFeature
import ContentCore
import ContentKit
import Foundation
import LanguageKit
import Testing

@Suite("CompositionSessionViewModel hint")
@MainActor
struct CompositionHintTests {
    @Test("revealHint は usedHint を立て、先頭許容文の最初の 1 語だけを出す")
    func revealHintShowsFirstWordOfFirstAcceptable() async throws {
        let (store, root) = try Self.makeStore(
            course: Self.compositionCourse(acceptable: ["See you later", "Catch you later"])
        )
        defer { try? FileManager.default.removeItem(at: root) }
        let viewModel = Self.makeViewModel(store: store)

        await viewModel.load()
        #expect(viewModel.hintText == nil)
        #expect(viewModel.usedHint == false)

        viewModel.revealHint()

        #expect(viewModel.usedHint)
        #expect(viewModel.hintText == "See")
    }

    @Test("空白区切りの最初の 1 語だけを切り出す")
    func revealHintSplitsOnSpace() async throws {
        let (store, root) = try Self.makeStore(
            course: Self.compositionCourse(acceptable: ["How are you"])
        )
        defer { try? FileManager.default.removeItem(at: root) }
        let viewModel = Self.makeViewModel(store: store)

        await viewModel.load()
        viewModel.revealHint()

        #expect(viewModel.hintText == "How")
    }

    @Test("acceptable が空なら hintText は nil のまま")
    func emptyAcceptableLeavesHintNil() async throws {
        let (store, root) = try Self.makeStore(
            course: Self.compositionCourse(acceptable: [])
        )
        defer { try? FileManager.default.removeItem(at: root) }
        let viewModel = Self.makeViewModel(store: store)

        await viewModel.load()
        viewModel.revealHint()

        #expect(viewModel.usedHint)
        #expect(viewModel.hintText == nil)
    }

    @Test("先頭文が空文字なら hintText は nil のまま")
    func emptyFirstAcceptableLeavesHintNil() async throws {
        let (store, root) = try Self.makeStore(
            course: Self.compositionCourse(acceptable: ["", "Hello there"])
        )
        defer { try? FileManager.default.removeItem(at: root) }
        let viewModel = Self.makeViewModel(store: store)

        await viewModel.load()
        viewModel.revealHint()

        #expect(viewModel.usedHint)
        #expect(viewModel.hintText == nil)
    }

    private static func makeViewModel(store: CourseStore) -> CompositionSessionViewModel {
        CompositionSessionViewModel(
            courseId: "course_c",
            lessonId: "lesson_c",
            itemId: "item_c",
            useCase: UnusedCompositionUseCase(),
            courseStore: store
        )
    }

    private static func compositionCourse(acceptable: [String]) throws -> CourseV1 {
        let item = try ItemV1(
            id: "item_c",
            kind: .composition,
            sentencePair: SentencePairV1(l1: "こんにちは", acceptable: acceptable)
        )
        return CourseV1(
            schemaVersion: 1,
            id: "course_c",
            languagePair: LanguagePair(
                sourceLanguage: try BCP47Language("ja"),
                targetLanguage: try BCP47Language("en")
            ),
            title: ["ja": "c"],
            units: [
                UnitV1(
                    id: "unit_c",
                    title: ["ja": "u"],
                    lessons: [LessonV1(id: "lesson_c", mode: .composition, items: [item])]
                ),
            ]
        )
    }

    private static func makeStore(course: CourseV1) throws -> (CourseStore, URL) {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("composition-hint-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let directory = root
            .appendingPathComponent(course.id, isDirectory: true)
            .appendingPathComponent("1", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try JSONEncoder().encode(course).write(to: directory.appendingPathComponent("index.json"))
        return (CourseStore(seed: SeedInstaller(bundle: .main), downloadsRoot: root), root)
    }
}

private final class UnusedCompositionUseCase: CompositionUseCase, @unchecked Sendable {
    func gradeTyped(
        item: ItemV1,
        stored: StoredCourse,
        lessonId: String,
        input: String,
        latencyMs: Int,
        usedHint: Bool
    ) async throws -> CompositionOutcome {
        _ = (item, stored, lessonId, input, latencyMs, usedHint)
        return CompositionOutcome(grade: .fail, quality: nil)
    }

    func startRecording(item: ItemV1) async throws -> URL {
        _ = item
        return URL(fileURLWithPath: "/tmp/unused.caf")
    }

    func finishRecording(
        item: ItemV1,
        stored: StoredCourse,
        lessonId: String,
        recordingURL: URL,
        latencyMs: Int,
        usedHint: Bool
    ) async throws -> CompositionOutcome {
        _ = (item, stored, lessonId, recordingURL, latencyMs, usedHint)
        return CompositionOutcome(grade: .fail, quality: nil)
    }
}
