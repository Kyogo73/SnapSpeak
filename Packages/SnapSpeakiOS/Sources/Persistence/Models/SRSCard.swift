import Foundation
import SwiftData

@Model
public final class SRSCard {
    @Attribute(.unique) public var cardKey: String
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
        relearnGateAt: Date?,
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
