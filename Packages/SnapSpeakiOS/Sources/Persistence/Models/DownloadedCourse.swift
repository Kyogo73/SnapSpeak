import Foundation
import SwiftData

@Model
public final class DownloadedCourse {
    @Attribute(.unique) public var courseId: String
    public var sourceLanguage: String
    public var targetLanguage: String
    public var revision: Int
    public var schemaVersion: Int
    public var releaseId: String
    public var localPath: String
    public var downloadedAt: Date
    public var bytes: Int64
    public var checksumSha256: String

    public init(
        courseId: String,
        sourceLanguage: String,
        targetLanguage: String,
        revision: Int,
        schemaVersion: Int,
        releaseId: String,
        localPath: String,
        downloadedAt: Date,
        bytes: Int64,
        checksumSha256: String
    ) {
        self.courseId = courseId
        self.sourceLanguage = sourceLanguage
        self.targetLanguage = targetLanguage
        self.revision = revision
        self.schemaVersion = schemaVersion
        self.releaseId = releaseId
        self.localPath = localPath
        self.downloadedAt = downloadedAt
        self.bytes = bytes
        self.checksumSha256 = checksumSha256
    }
}
