import Foundation
import SwiftData

@Model
public final class ReviewEvent {
    @Attribute(.unique) public var id: UUID
    public var cardKey: String
    public var courseId: String
    public var itemId: String
    public var contentRevision: Int
    public var skill: String
    public var quality: Int
    public var reviewedAt: Date
    public var clientSeq: Int64
    public var serverRevision: Int64?
    public var payloadSchemaVersion: Int
    public var payloadJSON: Data

    public init(
        id: UUID,
        cardKey: String,
        courseId: String,
        itemId: String,
        contentRevision: Int,
        skill: String,
        quality: Int,
        reviewedAt: Date,
        clientSeq: Int64,
        serverRevision: Int64?,
        payloadSchemaVersion: Int,
        payloadJSON: Data
    ) {
        self.id = id
        self.cardKey = cardKey
        self.courseId = courseId
        self.itemId = itemId
        self.contentRevision = contentRevision
        self.skill = skill
        self.quality = quality
        self.reviewedAt = reviewedAt
        self.clientSeq = clientSeq
        self.serverRevision = serverRevision
        self.payloadSchemaVersion = payloadSchemaVersion
        self.payloadJSON = payloadJSON
    }
}
