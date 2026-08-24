import ContentKit
import Foundation
import Testing

@Suite("DownloadManager courseSizeOnDisk")
struct DownloadManagerSizeTests {
    @Test("既知のファイルを持つコースディレクトリの合計バイト数を返す")
    func returnsAllocatedSizeOfKnownFiles() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("dl-size-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)

        let course = root.appendingPathComponent("course_known", isDirectory: true)
        try FileManager.default.createDirectory(at: course, withIntermediateDirectories: true)
        try Data(repeating: 0x61, count: 2_048).write(to: course.appendingPathComponent("index.json"))
        try Data(repeating: 0x62, count: 4_096).write(to: course.appendingPathComponent("audio.m4a"))

        let manager = DownloadManager(downloader: UnusedDownloader(), contentRoot: root)
        let size = await manager.courseSizeOnDisk(courseId: "course_known")
        #expect(size == allocatedSize(of: course))
        #expect(size > 0)
    }

    @Test("存在しない courseId は 0 を返す")
    func missingCourseReturnsZero() async {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("dl-size-missing-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)

        let manager = DownloadManager(downloader: UnusedDownloader(), contentRoot: root)
        let size = await manager.courseSizeOnDisk(courseId: "does_not_exist")
        #expect(size == 0)
    }

    @Test("tmp- プレフィクスの staging ディレクトリは含めない")
    func excludesTmpStagingSibling() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("dl-size-tmp-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)

        let course = root.appendingPathComponent("course_x", isDirectory: true)
        try FileManager.default.createDirectory(at: course, withIntermediateDirectories: true)
        try Data("course-bytes".utf8).write(to: course.appendingPathComponent("index.json"))

        let staging = root.appendingPathComponent("tmp-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: staging, withIntermediateDirectories: true)
        try Data(repeating: 0x63, count: 16_384).write(to: staging.appendingPathComponent("index.json"))

        let manager = DownloadManager(downloader: UnusedDownloader(), contentRoot: root)
        let size = await manager.courseSizeOnDisk(courseId: "course_x")
        #expect(size == allocatedSize(of: course))
        #expect(size < allocatedSize(of: course) + allocatedSize(of: staging))
        #expect(size != allocatedSize(of: staging))
    }

    private func allocatedSize(of directory: URL) -> Int64 {
        guard let enumerator = FileManager.default.enumerator(
            at: directory,
            includingPropertiesForKeys: [.totalFileAllocatedSizeKey, .fileAllocatedSizeKey]
        ) else { return 0 }
        var total: Int64 = 0
        for case let fileURL as URL in enumerator {
            let values = try? fileURL.resourceValues(
                forKeys: [.totalFileAllocatedSizeKey, .fileAllocatedSizeKey]
            )
            total += Int64(values?.totalFileAllocatedSize ?? values?.fileAllocatedSize ?? 0)
        }
        return total
    }
}

private struct UnusedDownloader: HTTPDownloading {
    func data(from url: URL) async throws -> Data {
        _ = url
        return Data()
    }
}
