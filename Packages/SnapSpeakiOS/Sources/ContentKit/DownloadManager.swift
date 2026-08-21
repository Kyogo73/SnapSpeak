import ContentCore
import Foundation
import LanguageKit

public actor DownloadManager {
    private let downloader: any HTTPDownloading
    private let contentRoot: URL
    private let fileManager: FileManager

    public init(
        downloader: any HTTPDownloading,
        contentRoot: URL,
        fileManager: FileManager = .default
    ) {
        self.downloader = downloader
        self.contentRoot = contentRoot
        self.fileManager = fileManager
    }

    public func localDirectory(courseId: String, revision: Int) -> URL {
        contentRoot
            .appendingPathComponent(courseId, isDirectory: true)
            .appendingPathComponent(String(revision), isDirectory: true)
    }

    public func download(
        courseId: String,
        languagePair: LanguagePair,
        release: CourseRelease
    ) async throws -> URL {
        _ = languagePair
        try FileStaging.requireSpace(bytes: Int64(release.bytes), at: contentRoot)
        try fileManager.createDirectory(at: contentRoot, withIntermediateDirectories: true)

        let staging = contentRoot.appendingPathComponent("tmp-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: staging, withIntermediateDirectories: true)
        do {
            guard let remote = URL(string: release.contentUrl) else {
                throw DownloadError.httpStatus(400)
            }
            let data = try await downloader.data(from: remote)
            let index = staging.appendingPathComponent("index.json")
            try data.write(to: index, options: .atomic)
            let destination = localDirectory(courseId: courseId, revision: release.revision)
            do {
                try FileStaging.commitDirectory(
                    staging: staging,
                    to: destination,
                    checksumFileName: "index.json",
                    expectedHex: release.checksumSha256,
                    fileManager: fileManager
                )
            } catch FileStagingError.checksumMismatch {
                throw DownloadError.checksumMismatch
            } catch let FileStagingError.insufficientDiskSpace(required, available) {
                throw DownloadError.insufficientDiskSpace(required: required, available: available)
            }
            return destination
        } catch {
            try? fileManager.removeItem(at: staging)
            throw error
        }
    }

    public func deleteCourse(courseId: String) throws {
        let directory = contentRoot.appendingPathComponent(courseId, isDirectory: true)
        if fileManager.fileExists(atPath: directory.path) {
            try fileManager.removeItem(at: directory)
        }
    }

    /// Drops oldest downloaded courses until `maxBytes` is met. Seed content is not under `contentRoot`.
    public func evictLRU(maxBytes: Int64, lastUsed: [String: Date]) throws {
        let courses = (try? fileManager.contentsOfDirectory(
            at: contentRoot,
            includingPropertiesForKeys: [.isDirectoryKey, .totalFileAllocatedSizeKey],
            options: [.skipsHiddenFiles]
        )) ?? []
        let ranked = courses
            .filter { url in
                !url.lastPathComponent.hasPrefix("tmp-")
            }
            .sorted { lhs, rhs in
                let left = lastUsed[lhs.lastPathComponent] ?? .distantPast
                let right = lastUsed[rhs.lastPathComponent] ?? .distantPast
                return left < right
            }
        var total = ranked.reduce(Int64(0)) { partial, url in
            partial + (directorySize(url) ?? 0)
        }
        for url in ranked where total > maxBytes {
            let size = directorySize(url) ?? 0
            try fileManager.removeItem(at: url)
            total -= size
        }
    }

    private func directorySize(_ url: URL) -> Int64? {
        guard let enumerator = fileManager.enumerator(
            at: url,
            includingPropertiesForKeys: [.totalFileAllocatedSizeKey, .fileAllocatedSizeKey]
        ) else { return nil }
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
