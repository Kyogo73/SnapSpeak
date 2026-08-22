import Foundation
import Persistence
import SRSKit

// PersistenceActorTests / PersistenceHabitTests 共有のヘルパー。

func makeActor() throws -> PersistenceActor {
    let container = try PersistenceActor.makeContainer(inMemory: true)
    return PersistenceActor(modelContainer: container)
}

func foldRequest(cardKey: String, now: Date, itemId: String = "crs_daily_ja_en_item_p_001") -> SRSCardFoldRequest {
    SRSCardFoldRequest(
        cardKey: cardKey,
        sourceLanguage: "ja",
        targetLanguage: "en",
        courseId: "course_daily_ja_en",
        itemId: itemId,
        skill: Skill.shadowing.rawValue,
        contentRevision: 1,
        inheritSRS: true,
        now: now,
        timeZoneIdentifier: "UTC",
        dayBoundaryHour: 4
    )
}

func foldNewCard(
    actor: PersistenceActor,
    itemId: String,
    reviewedAt: Date,
    quality: ReviewQuality
) async throws -> SRSCardDTO {
    let cardKey = CardKey(
        pairKey: "ja>en",
        courseId: "course_daily_ja_en",
        itemId: itemId,
        skill: .shadowing
    ).raw
    let event = ReviewEventDTO(
        id: UUID(),
        cardKey: cardKey,
        quality: quality.rawValue,
        reviewedAt: reviewedAt,
        clientSeq: 1,
        serverRevision: nil,
        contentRevision: 1
    )
    _ = try await actor.appendReviewEvent(
        ReviewEventWrite(
            event: event,
            courseId: "course_daily_ja_en",
            itemId: itemId,
            skill: Skill.shadowing.rawValue
        )
    )
    return try await actor.foldSRSCard(foldRequest(cardKey: cardKey, now: reviewedAt, itemId: itemId))
}

func attemptWrite(itemId: String, createdAt: Date) -> LessonAttemptWrite {
    LessonAttemptWrite(
        courseId: "course_daily_ja_en",
        lessonId: "lesson_01_shadowing",
        itemId: itemId,
        contentRevision: 1,
        languagePairKey: "ja>en",
        skill: Skill.shadowing.rawValue,
        createdAt: createdAt,
        durationMs: 1_000,
        payloadSchemaVersion: 1,
        payloadJSON: Data("{}".utf8)
    )
}
