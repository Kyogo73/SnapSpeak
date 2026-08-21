import Foundation
import SwiftData

@Model
public final class LessonAttempt {
    @Attribute(.unique) public var id: UUID
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
