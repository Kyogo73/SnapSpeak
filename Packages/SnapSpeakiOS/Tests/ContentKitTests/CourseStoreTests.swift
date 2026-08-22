import ContentCore
import ContentKit
import Foundation
import LanguageKit
import Testing

@Suite("CourseStore catalog")
struct CourseStoreTests {
    @Test("同 revision の downloaded は sidecar の releaseId で tie-break する")
    func sameRevisionDownloadedUsesSidecarReleaseId() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("course-store-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)

        try writeDownloaded(
            root: root,
            folder: "alias_a",
            revision: 2,
            releaseId: "rel_a",
            courseId: "course_x"
        )
        try writeDownloaded(
            root: root,
            folder: "alias_b",
            revision: 2,
            releaseId: "rel_b",
            courseId: "course_x"
        )

        let store = CourseStore(seed: SeedInstaller(bundle: .main), downloadsRoot: root)
        let courses = await store.allCourses().filter { $0.course.id == "course_x" }
        #expect(courses.count == 1)
        #expect(courses[0].releaseId == "rel_b")
        #expect(courses[0].revision == 2)
        #expect(courses[0].origin == .downloaded)
    }

    @Test("sidecar の releaseId を StoredCourse に反映し revision ディレクトリ名は使わない")
    func storedCourseUsesSidecarReleaseIdNotDirectoryName() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("course-store-meta-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try writeDownloaded(
            root: root,
            folder: "course_x",
            revision: 2,
            releaseId: "course_x__r2",
            courseId: "course_x"
        )

        let store = CourseStore(seed: SeedInstaller(bundle: .main), downloadsRoot: root)
        let courses = await store.allCourses().filter { $0.course.id == "course_x" }
        try #require(courses.count == 1)
        #expect(courses[0].releaseId == "course_x__r2")
        #expect(courses[0].releaseId != "2")
    }

    private func writeDownloaded(
        root: URL,
        folder: String,
        revision: Int,
        releaseId: String,
        courseId: String
    ) throws {
        let directory = root
            .appendingPathComponent(folder, isDirectory: true)
            .appendingPathComponent("\(revision)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let course = try CourseV1(
            schemaVersion: 1,
            id: courseId,
            languagePair: LanguagePair(
                sourceLanguage: try BCP47Language("ja"),
                targetLanguage: try BCP47Language("en")
            ),
            title: ["ja": "t"],
            units: [
                UnitV1(
                    id: "u",
                    title: ["ja": "u"],
                    lessons: [
                        LessonV1(
                            id: "l",
                            mode: .composition,
                            items: [
                                ItemV1(
                                    id: "i",
                                    kind: .composition,
                                    sentencePair: SentencePairV1(l1: "こんにちは", acceptable: ["Hello"])
                                ),
                            ]
                        ),
                    ]
                ),
            ]
        )
        try JSONEncoder().encode(course).write(to: directory.appendingPathComponent("index.json"))
        let meta = ReleaseMeta(inheritSRS: true, releaseId: releaseId, revision: revision)
        try JSONEncoder().encode(meta).write(to: directory.appendingPathComponent(ReleaseMeta.fileName))
    }
}
