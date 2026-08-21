import ContentCore
import Foundation

public protocol HTTPDownloading: Sendable {
    func data(from url: URL) async throws -> Data
}

public struct URLSessionDownloader: HTTPDownloading {
    public init() {}

    public func data(from url: URL) async throws -> Data {
        let (data, response) = try await URLSession.shared.data(from: url)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw DownloadError.httpStatus(http.statusCode)
        }
        return data
    }
}

public enum DownloadError: Error, Sendable, Equatable {
    case httpStatus(Int)
    case checksumMismatch
    case insufficientDiskSpace(required: Int64, available: Int64)
}

public enum FileStagingError: Error, Sendable, Equatable {
    case checksumMismatch
    case insufficientDiskSpace(required: Int64, available: Int64)
    case missingChecksumFile
}

/// Checksum staging, then `replaceItemAt` (atomic on Apple platforms). Failure leaves the previous directory in place.
public enum FileStaging: Sendable {
    public static func availableBytes(at url: URL) throws -> Int64 {
        let values = try url.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
        if let capacity = values.volumeAvailableCapacityForImportantUsage {
            return capacity
        }
        let fallback = try url.resourceValues(forKeys: [.volumeAvailableCapacityKey])
        return Int64(fallback.volumeAvailableCapacity ?? 0)
    }

    public static func requireSpace(bytes: Int64, at url: URL) throws {
        let available = try availableBytes(at: url)
        if available < bytes {
            throw FileStagingError.insufficientDiskSpace(required: bytes, available: available)
        }
    }

    public static func excludeFromBackup(_ url: URL) throws {
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        var mutable = url
        try mutable.setResourceValues(values)
    }

    /// Verifies `checksumFileName` inside `staging`, then atomically replaces `finalDirectory`.
    public static func commitDirectory(
        staging: URL,
        to finalDirectory: URL,
        checksumFileName: String,
        expectedHex: String,
        fileManager: FileManager = .default
    ) throws {
        let checksumFile = staging.appendingPathComponent(checksumFileName)
        guard fileManager.fileExists(atPath: checksumFile.path) else {
            throw FileStagingError.missingChecksumFile
        }
        let data = try Data(contentsOf: checksumFile)
        guard Checksum.verify(data: data, expectedHex: expectedHex) else {
            throw FileStagingError.checksumMismatch
        }
        try excludeFromBackup(staging)
        let parent = finalDirectory.deletingLastPathComponent()
        try fileManager.createDirectory(at: parent, withIntermediateDirectories: true)
        if fileManager.fileExists(atPath: finalDirectory.path) {
            _ = try fileManager.replaceItemAt(finalDirectory, withItemAt: staging)
        } else {
            try fileManager.moveItem(at: staging, to: finalDirectory)
        }
        try excludeFromBackup(finalDirectory)
    }

    /// Removes leftover `tmp-*` staging directories left by an interrupted download.
    public static func cleanupStaleStaging(
        in directory: URL,
        prefix: String = "tmp-",
        fileManager: FileManager = .default
    ) {
        let items = (try? fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )) ?? []
        for url in items where url.lastPathComponent.hasPrefix(prefix) {
            try? fileManager.removeItem(at: url)
        }
    }
}
