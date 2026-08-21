import Foundation
import Persistence
import SRSKit
import Testing

@Suite("Persistence VersionedSchema v1")
struct PersistenceActorTests {
    private func makeActor() throws -> PersistenceActor {
        let container = try PersistenceActor.makeContainer(inMemory: true)
        return PersistenceActor(modelContainer: container)
    }

    @Test("append attempt then fetch DTO with payload pairing")
    func appendAttemptRoundTrip() async throws {
        let actor = try makeActor()
        let payload = Data(#"{"payloadSchemaVersion":1,"scriptMatchRate":0.8}"#.utf8)
        let write = LessonAttemptWrite(
            courseId: "course_daily_ja_en",
            lessonId: "lesson_01_shadowing",
            itemId: "crs_daily_ja_en_item_p_001",
            contentRevision: 1,
            languagePairKey: "ja>en",
            skill: Skill.shadowing.rawValue,
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            durationMs: 21_000,
            payloadSchemaVersion: 1,
            payloadJSON: payload
        )
        let stored = try await actor.appendAttempt(write)
        #expect(stored.id == write.id)
        #expect(stored.payloadSchemaVersion == 1)
        #expect(stored.payloadJSON == payload)
        let fetched = try await actor.fetchAttempt(id: write.id)
        #expect(fetched == stored)
        let again = try await actor.appendAttempt(write)
        #expect(again.id == stored.id)
    }

    @Test("append review event then fold SRSCard")
    func appendReviewThenFoldCard() async throws {
        let actor = try makeActor()
        let cardKey = CardKey(
            pairKey: "ja>en",
            courseId: "course_daily_ja_en",
            itemId: "crs_daily_ja_en_item_p_001",
            skill: .shadowing
        ).raw
        let reviewedAt = Date(timeIntervalSince1970: 1_700_000_400)
        let event = ReviewEventDTO(
            id: UUID(),
            cardKey: cardKey,
            quality: ReviewQuality.good.rawValue,
            reviewedAt: reviewedAt,
            clientSeq: 1,
            serverRevision: nil,
            contentRevision: 1
        )
        let stored = try await actor.appendReviewEvent(
            ReviewEventWrite(
                event: event,
                courseId: "course_daily_ja_en",
                itemId: "crs_daily_ja_en_item_p_001",
                skill: Skill.shadowing.rawValue
            )
        )
        #expect(stored.id == event.id)
        #expect(stored.quality == ReviewQuality.good.rawValue)

        let card = try await actor.foldSRSCard(
            SRSCardFoldRequest(
                cardKey: cardKey,
                sourceLanguage: "ja",
                targetLanguage: "en",
                courseId: "course_daily_ja_en",
                itemId: "crs_daily_ja_en_item_p_001",
                skill: Skill.shadowing.rawValue,
                contentRevision: 1,
                inheritSRS: true,
                now: reviewedAt,
                timeZoneIdentifier: "UTC",
                dayBoundaryHour: 4
            )
        )
        #expect(card.cardKey == cardKey)
        #expect(card.lastQuality == ReviewQuality.good.rawValue)
        #expect(card.repetitions == 1)
        #expect(card.intervalDays == 1)
        #expect(card.easiness > SRSState.minimumEasiness)

        let fetched = try await actor.fetchSRSCard(cardKey: cardKey)
        #expect(fetched?.lastQuality == card.lastQuality)
        #expect(fetched?.repetitions == 1)
    }

    @Test("inheritSRS false folds only matching contentRevision events")
    func incompatibleRevisionDoesNotFoldOldEvents() async throws {
        let actor = try makeActor()
        let cardKey = CardKey(
            pairKey: "ja>en",
            courseId: "course_daily_ja_en",
            itemId: "crs_daily_ja_en_item_p_001",
            skill: .shadowing
        ).raw
        let reviewedAt = Date(timeIntervalSince1970: 1_700_000_400)
        let oldEvent = ReviewEventDTO(
            id: UUID(),
            cardKey: cardKey,
            quality: ReviewQuality.easy.rawValue,
            reviewedAt: reviewedAt,
            clientSeq: 1,
            serverRevision: nil,
            contentRevision: 1
        )
        _ = try await actor.appendReviewEvent(
            ReviewEventWrite(
                event: oldEvent,
                courseId: "course_daily_ja_en",
                itemId: "crs_daily_ja_en_item_p_001",
                skill: Skill.shadowing.rawValue
            )
        )
        let card = try await actor.foldSRSCard(
            SRSCardFoldRequest(
                cardKey: cardKey,
                sourceLanguage: "ja",
                targetLanguage: "en",
                courseId: "course_daily_ja_en",
                itemId: "crs_daily_ja_en_item_p_001",
                skill: Skill.shadowing.rawValue,
                contentRevision: 2,
                inheritSRS: false,
                now: reviewedAt,
                timeZoneIdentifier: "UTC",
                dayBoundaryHour: 4
            )
        )
        #expect(card.repetitions == 0)
        #expect(card.lastQuality == nil)
        #expect(card.inheritSRS == false)
        let storedEvents = try await actor.reviewEvents(forCardKey: cardKey)
        #expect(storedEvents.count == 1)
        #expect(storedEvents[0].contentRevision == 1)
    }
}
