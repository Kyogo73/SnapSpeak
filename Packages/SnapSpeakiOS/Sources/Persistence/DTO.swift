import Foundation
import SRSKit

/// Sendable snapshot of a persisted `LessonAttempt`. `payloadJSON` always travels with
/// `payloadSchemaVersion` so later schema changes can be decoded without guessing.
public struct LessonAttemptDTO: Sendable, Equatable, Identifiable {
    public var id: UUID
    public var courseId: String
    public var lessonId: String
    public var itemId: String
    public var contentRevision: Int
    public var languagePairKey: String
    public var skill: String
    public var createdAt: Date
    public var durationMs: Int
    public var payloadSchemaVersion: Int
    public var payloadJSON: Data

    public init(
        id: UUID,
        courseId: String,
        lessonId: String,
        itemId: String,
        contentRevision: Int,
        languagePairKey: String,
        skill: String,
        createdAt: Date,
        durationMs: Int,
        payloadSchemaVersion: Int,
        payloadJSON: Data
    ) {
        self.id = id
        self.courseId = courseId
        self.lessonId = lessonId
        self.itemId = itemId
        self.contentRevision = contentRevision
        self.languagePairKey = languagePairKey
        self.skill = skill
        self.createdAt = createdAt
        self.durationMs = durationMs
        self.payloadSchemaVersion = payloadSchemaVersion
        self.payloadJSON = payloadJSON
    }
}

/// Append-only write. Same payload pairing rules as `LessonAttemptDTO`.
public struct LessonAttemptWrite: Sendable, Equatable {
    public var id: UUID
    public var courseId: String
    public var lessonId: String
    public var itemId: String
    public var contentRevision: Int
    public var languagePairKey: String
    public var skill: String
    public var createdAt: Date
    public var durationMs: Int
    public var payloadSchemaVersion: Int
    public var payloadJSON: Data

    public init(
        id: UUID = UUID(),
        courseId: String,
        lessonId: String,
        itemId: String,
        contentRevision: Int,
        languagePairKey: String,
        skill: String,
        createdAt: Date,
        durationMs: Int,
        payloadSchemaVersion: Int,
        payloadJSON: Data
    ) {
        self.id = id
        self.courseId = courseId
        self.lessonId = lessonId
        self.itemId = itemId
        self.contentRevision = contentRevision
        self.languagePairKey = languagePairKey
        self.skill = skill
        self.createdAt = createdAt
        self.durationMs = durationMs
        self.payloadSchemaVersion = payloadSchemaVersion
        self.payloadJSON = payloadJSON
    }
}

/// Extra fields stored beside `ReviewEventDTO` so the SwiftData row can be rebuilt.
public struct ReviewEventWrite: Sendable, Equatable {
    public var event: ReviewEventDTO
    public var courseId: String
    public var itemId: String
    public var skill: String
    public var payloadSchemaVersion: Int
    public var payloadJSON: Data

    public init(
        event: ReviewEventDTO,
        courseId: String,
        itemId: String,
        skill: String,
        payloadSchemaVersion: Int = 1,
        payloadJSON: Data = Data("{}".utf8)
    ) {
        self.event = event
        self.courseId = courseId
        self.itemId = itemId
        self.skill = skill
        self.payloadSchemaVersion = payloadSchemaVersion
        self.payloadJSON = payloadJSON
    }
}

public struct EntitlementCacheDTO: Sendable, Equatable {
    public var isPro: Bool
    public var expirationDate: Date?
    public var billingRetryExpired: Bool
    public var inGracePeriod: Bool
    public var updatedAt: Date

    public init(
        isPro: Bool,
        expirationDate: Date?,
        billingRetryExpired: Bool,
        inGracePeriod: Bool,
        updatedAt: Date
    ) {
        self.isPro = isPro
        self.expirationDate = expirationDate
        self.billingRetryExpired = billingRetryExpired
        self.inGracePeriod = inGracePeriod
        self.updatedAt = updatedAt
    }
}

public struct DownloadedCourseDTO: Sendable, Equatable, Identifiable {
    public var id: String { courseId }
    public var courseId: String
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
