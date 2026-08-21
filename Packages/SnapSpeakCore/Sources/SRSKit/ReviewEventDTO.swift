import Foundation

public struct ReviewEventDTO: Sendable, Equatable, Identifiable {
    public var id: UUID
    public var cardKey: String
    public var quality: Int
    public var reviewedAt: Date
    public var clientSeq: Int64
    public var serverRevision: Int64?
    public var contentRevision: Int

    public init(
        id: UUID,
        cardKey: String,
        quality: Int,
        reviewedAt: Date,
        clientSeq: Int64,
        serverRevision: Int64?,
        contentRevision: Int
    ) {
        self.id = id
        self.cardKey = cardKey
        self.quality = quality
        self.reviewedAt = reviewedAt
        self.clientSeq = clientSeq
        self.serverRevision = serverRevision
        self.contentRevision = contentRevision
    }
}
