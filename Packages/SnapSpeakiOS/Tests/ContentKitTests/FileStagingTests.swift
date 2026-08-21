import ContentCore
import ContentKit
import Foundation
import LanguageKit
import Testing

@Suite("ContentKit atomic staging")
struct FileStagingTests {
    @Test("successful staging replaces destination and excludes backup")
    func commitReplacesDestination() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("staging-success-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)

        let finalDir = root.appendingPathComponent("course", isDirectory: true)
        try FileManager.default.createDirectory(at: finalDir, withIntermediateDirectories: true)
        try Data("old-index".utf8).write(to: finalDir.appendingPathComponent("index.json"))

        let staging = root.appendingPathComponent("staging", isDirectory: true)
        try FileManager.default.createDirectory(at: staging, withIntermediateDirectories: true)
        let payload = Data("new-index".utf8)
        try payload.write(to: staging.appendingPathComponent("index.json"))
        let digest = Checksum.sha256Hex(of: payload)

        try FileStaging.commitDirectory(
            staging: staging,
            to: finalDir,
            checksumFileName: "index.json",
            expectedHex: digest
        )

        let stored = try Data(contentsOf: finalDir.appendingPathComponent("index.json"))
        #expect(stored == payload)
        #expect(!FileManager.default.fileExists(atPath: staging.path))
        let values = try finalDir.resourceValues(forKeys: [.isExcludedFromBackupKey])
        #expect(values.isExcludedFromBackup == true)
    }

    @Test("checksum failure keeps the previous directory")
    func checksumFailureKeepsOld() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("staging-fail-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)

        let finalDir = root.appendingPathComponent("course", isDirectory: true)
        try FileManager.default.createDirectory(at: finalDir, withIntermediateDirectories: true)
        let old = Data("keep-me".utf8)
        try old.write(to: finalDir.appendingPathComponent("index.json"))

        let staging = root.appendingPathComponent("staging", isDirectory: true)
        try FileManager.default.createDirectory(at: staging, withIntermediateDirectories: true)
        try Data("tampered".utf8).write(to: staging.appendingPathComponent("index.json"))

        do {
            try FileStaging.commitDirectory(
                staging: staging,
                to: finalDir,
                checksumFileName: "index.json",
                expectedHex: "deadbeef"
            )
            Issue.record("expected checksum mismatch")
        } catch FileStagingError.checksumMismatch {
            let stored = try Data(contentsOf: finalDir.appendingPathComponent("index.json"))
            #expect(stored == old)
            #expect(FileManager.default.fileExists(atPath: staging.path))
        }
    }

    @Test("stale tmp staging directories are removed")
    func cleanupStaleStagingRemovesTmp() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("staging-cleanup-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let stale = root.appendingPathComponent("tmp-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: stale, withIntermediateDirectories: true)
        try Data("leftover".utf8).write(to: stale.appendingPathComponent("index.json"))
        let keep = root.appendingPathComponent("course", isDirectory: true)
        try FileManager.default.createDirectory(at: keep, withIntermediateDirectories: true)

        FileStaging.cleanupStaleStaging(in: root)

        #expect(!FileManager.default.fileExists(atPath: stale.path))
        #expect(FileManager.default.fileExists(atPath: keep.path))
    }
}

private struct MockDownloader: HTTPDownloading {
    var payload: Data

    func data(from url: URL) async throws -> Data {
        _ = url
        return payload
    }
}

@Suite("ContentKit download manager")
struct DownloadManagerTests {
    @Test("mock download stages index.json atomically")
    func mockDownloadCommits() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("dl-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let payload = Data(#"{"schemaVersion":1,"id":"c"}"#.utf8)
        let digest = Checksum.sha256Hex(of: payload)
        let manager = DownloadManager(
            downloader: MockDownloader(payload: payload),
            contentRoot: root
        )
        let pair = try LanguagePair(
            sourceLanguage: BCP47Language("ja"),
            targetLanguage: BCP47Language("en")
        )
        let release = CourseRelease(
            releaseId: "c__r1",
            revision: 1,
            schemaVersion: 1,
            minAppVersion: AppVersion(major: 1, minor: 0, patch: 0),
            maxAppVersion: nil,
            contentUrl: "https://cdn.example.com/c/r1/index.json",
            bytes: payload.count,
            checksumSha256: digest,
            inheritSRS: false
        )
        let destination = try await manager.download(
            courseId: "c",
            languagePair: pair,
            release: release
        )
        let stored = try Data(contentsOf: destination.appendingPathComponent("index.json"))
        #expect(stored == payload)
        let metaData = try Data(contentsOf: destination.appendingPathComponent(ReleaseMeta.fileName))
        let meta = try JSONDecoder().decode(ReleaseMeta.self, from: metaData)
        #expect(meta.inheritSRS == false)
        #expect(meta.releaseId == "c__r1")
        #expect(meta.revision == 1)
    }
}
