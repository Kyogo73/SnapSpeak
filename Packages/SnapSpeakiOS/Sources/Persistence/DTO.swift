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

public struct SRSCardDTO: Sendable, Equatable {
    public var cardKey: String
    public var sourceLanguage: String
    public var targetLanguage: String
    public var courseId: String
    public var itemId: String
    public var skill: String
    public var contentRevision: Int
    public var inheritSRS: Bool
    public var easiness: Double
    public var intervalDays: Int
    public var repetitions: Int
    public var dueAt: Date
    public var relearnGateAt: Date?
    public var lastReviewedAt: Date?
    public var lastQuality: Int?
    public var foldedThroughRevision: Int64?

    public init(
        cardKey: String,
        sourceLanguage: String,
        targetLanguage: String,
        courseId: String,
        itemId: String,
        skill: String,
        contentRevision: Int,
        inheritSRS: Bool,
        easiness: Double,
        intervalDays: Int,
        repetitions: Int,
        dueAt: Date,
        relearnGateAt: Date? = nil,
        lastReviewedAt: Date?,
        lastQuality: Int?,
        foldedThroughRevision: Int64?
    ) {
        self.cardKey = cardKey
        self.sourceLanguage = sourceLanguage
        self.targetLanguage = targetLanguage
        self.courseId = courseId
        self.itemId = itemId
        self.skill = skill
        self.contentRevision = contentRevision
        self.inheritSRS = inheritSRS
        self.easiness = easiness
        self.intervalDays = intervalDays
        self.repetitions = repetitions
        self.dueAt = dueAt
        self.relearnGateAt = relearnGateAt
        self.lastReviewedAt = lastReviewedAt
        self.lastQuality = lastQuality
        self.foldedThroughRevision = foldedThroughRevision
    }
}

public struct UserSettingsDTO: Sendable, Equatable {
    public var sourceLanguage: String
    public var targetLanguage: String
    public var captionsEnabled: Bool
    public var defaultRate: Float
    public var reminderHour: Int?
    public var reminderMinute: Int
    public var reminderEnabled: Bool
    public var dailyGoalItems: Int
    public var onboardingCompletedAt: Date?
    public var lastKnownStreakDays: Int
    public var fieldRevisionsJSON: Data
    public var deletedAt: Date?

    public init(
        sourceLanguage: String,
        targetLanguage: String,
        captionsEnabled: Bool,
        defaultRate: Float,
        reminderHour: Int?,
        reminderMinute: Int = 0,
        reminderEnabled: Bool = false,
        dailyGoalItems: Int = 10,
        onboardingCompletedAt: Date? = nil,
        lastKnownStreakDays: Int = 0,
        fieldRevisionsJSON: Data,
        deletedAt: Date?
    ) {
        self.sourceLanguage = sourceLanguage
        self.targetLanguage = targetLanguage
        self.captionsEnabled = captionsEnabled
        self.defaultRate = defaultRate
        self.reminderHour = reminderHour
        self.reminderMinute = reminderMinute
        self.reminderEnabled = reminderEnabled
        self.dailyGoalItems = dailyGoalItems
        self.onboardingCompletedAt = onboardingCompletedAt
        self.lastKnownStreakDays = lastKnownStreakDays
        self.fieldRevisionsJSON = fieldRevisionsJSON
        self.deletedAt = deletedAt
    }

    public static let phase1Default = UserSettingsDTO(
        sourceLanguage: "ja",
        targetLanguage: "en",
        captionsEnabled: true,
        defaultRate: 1.0,
        reminderHour: nil,
        reminderMinute: 0,
        reminderEnabled: false,
        dailyGoalItems: 10,
        onboardingCompletedAt: nil,
        lastKnownStreakDays: 0,
        fieldRevisionsJSON: Data("{}".utf8),
        deletedAt: nil
    )
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

public struct SRSCardFoldRequest: Sendable, Equatable {
    public var cardKey: String
    public var sourceLanguage: String
    public var targetLanguage: String
    public var courseId: String
    public var itemId: String
    public var skill: String
    public var contentRevision: Int
    public var inheritSRS: Bool
    public var now: Date
    public var timeZoneIdentifier: String
    public var dayBoundaryHour: Int

    public init(
        cardKey: String,
        sourceLanguage: String,
        targetLanguage: String,
        courseId: String,
        itemId: String,
        skill: String,
        contentRevision: Int,
        inheritSRS: Bool,
        now: Date,
        timeZoneIdentifier: String,
        dayBoundaryHour: Int = 4
    ) {
        self.cardKey = cardKey
        self.sourceLanguage = sourceLanguage
        self.targetLanguage = targetLanguage
        self.courseId = courseId
        self.itemId = itemId
        self.skill = skill
        self.contentRevision = contentRevision
        self.inheritSRS = inheritSRS
        self.now = now
        self.timeZoneIdentifier = timeZoneIdentifier
        self.dayBoundaryHour = dayBoundaryHour
    }
}

enum PersistenceMapping {
    static func attemptDTO(_ model: LessonAttempt) -> LessonAttemptDTO {
        LessonAttemptDTO(
            id: model.id,
            courseId: model.courseId,
            lessonId: model.lessonId,
            itemId: model.itemId,
            contentRevision: model.contentRevision,
            languagePairKey: model.languagePairKey,
            skill: model.skill,
            createdAt: model.createdAt,
            durationMs: model.durationMs,
            payloadSchemaVersion: model.payloadSchemaVersion,
            payloadJSON: model.payloadJSON
        )
    }

    static func reviewDTO(_ model: ReviewEvent) -> ReviewEventDTO {
        ReviewEventDTO(
            id: model.id,
            cardKey: model.cardKey,
            quality: model.quality,
            reviewedAt: model.reviewedAt,
            clientSeq: model.clientSeq,
            serverRevision: model.serverRevision,
            contentRevision: model.contentRevision
        )
    }

    static func cardDTO(_ model: SRSCard) -> SRSCardDTO {
        SRSCardDTO(
            cardKey: model.cardKey,
            sourceLanguage: model.sourceLanguage,
            targetLanguage: model.targetLanguage,
            courseId: model.courseId,
            itemId: model.itemId,
            skill: model.skill,
            contentRevision: model.contentRevision,
            inheritSRS: model.inheritSRS,
            easiness: model.easiness,
            intervalDays: model.intervalDays,
            repetitions: model.repetitions,
            dueAt: model.dueAt,
            relearnGateAt: model.relearnGateAt,
            lastReviewedAt: model.lastReviewedAt,
            lastQuality: model.lastQuality,
            foldedThroughRevision: model.foldedThroughRevision
        )
    }

    static func settingsDTO(_ model: UserSettings) -> UserSettingsDTO {
        UserSettingsDTO(
            sourceLanguage: model.sourceLanguage,
            targetLanguage: model.targetLanguage,
            captionsEnabled: model.captionsEnabled,
            defaultRate: model.defaultRate,
            reminderHour: model.reminderHour,
            reminderMinute: model.reminderMinute,
            reminderEnabled: model.reminderEnabled,
            dailyGoalItems: model.dailyGoalItems,
            onboardingCompletedAt: model.onboardingCompletedAt,
            lastKnownStreakDays: model.lastKnownStreakDays,
            fieldRevisionsJSON: model.fieldRevisionsJSON,
            deletedAt: model.deletedAt
        )
    }

    static func downloadedDTO(_ model: DownloadedCourse) -> DownloadedCourseDTO {
        DownloadedCourseDTO(
            courseId: model.courseId,
            sourceLanguage: model.sourceLanguage,
            targetLanguage: model.targetLanguage,
            revision: model.revision,
            schemaVersion: model.schemaVersion,
            releaseId: model.releaseId,
            localPath: model.localPath,
            downloadedAt: model.downloadedAt,
            bytes: model.bytes,
            checksumSha256: model.checksumSha256
        )
    }
}
