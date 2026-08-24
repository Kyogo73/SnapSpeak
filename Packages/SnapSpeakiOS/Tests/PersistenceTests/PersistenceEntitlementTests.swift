import Foundation
import Persistence
import SRSKit
import Testing

@Suite("Persistence entitlement & daily composition count")
struct PersistenceEntitlementTests {
    @Test("compositionAttemptCount は学習日 04:00 境界と skill で絞る")
    func compositionCountUsesStudyDayAndSkill() async throws {
        let actor = try makeActor()
        let beforeBoundary = utcDate(2026, 4, 6, 3, 59)
        let onBoundary = utcDate(2026, 4, 6, 4, 0)
        let afternoon = utcDate(2026, 4, 6, 15, 0)
        let nextMorning = utcDate(2026, 4, 7, 4, 0)

        _ = try await actor.appendAttempt(
            compositionWrite(itemId: "prev_day", createdAt: beforeBoundary)
        )
        _ = try await actor.appendAttempt(
            compositionWrite(itemId: "first", createdAt: onBoundary)
        )
        _ = try await actor.appendAttempt(
            compositionWrite(itemId: "second", createdAt: afternoon)
        )
        _ = try await actor.appendAttempt(
            attemptWrite(itemId: "shadowing_same_day", createdAt: afternoon)
        )
        _ = try await actor.appendAttempt(
            compositionWrite(itemId: "next_day", createdAt: nextMorning)
        )

        let now = utcDate(2026, 4, 6, 22, 0)
        let count = try await actor.compositionAttemptCount(now: now, timeZoneIdentifier: "UTC")
        #expect(count == 2)

        let previousDay = try await actor.compositionAttemptCount(
            now: beforeBoundary,
            timeZoneIdentifier: "UTC"
        )
        #expect(previousDay == 1)
    }

    @Test("compositionAttemptCount は半開区間 [start, end)")
    func compositionCountHalfOpenInterval() async throws {
        let actor = try makeActor()
        let start = utcDate(2026, 4, 6, 4, 0)
        let mid = utcDate(2026, 4, 6, 12, 0)
        let end = utcDate(2026, 4, 7, 4, 0)
        _ = try await actor.appendAttempt(compositionWrite(itemId: "start", createdAt: start))
        _ = try await actor.appendAttempt(compositionWrite(itemId: "mid", createdAt: mid))
        _ = try await actor.appendAttempt(compositionWrite(itemId: "end", createdAt: end))
        #expect(try await actor.compositionAttemptCount(from: start, to: end) == 2)
    }

    @Test("EntitlementCache の upsert と load")
    func entitlementCacheRoundTrip() async throws {
        let actor = try makeActor()
        #expect(try await actor.loadEntitlementCache() == nil)
        let first = EntitlementCacheDTO(
            isPro: true,
            expirationDate: utcDate(2026, 5, 1, 4, 0),
            billingRetryExpired: false,
            inGracePeriod: true,
            updatedAt: utcDate(2026, 4, 6, 10, 0)
        )
        let saved = try await actor.upsertEntitlementCache(first)
        #expect(saved == first)
        let loaded = try await actor.loadEntitlementCache()
        #expect(loaded == first)

        let updated = EntitlementCacheDTO(
            isPro: false,
            expirationDate: nil,
            billingRetryExpired: true,
            inGracePeriod: false,
            updatedAt: utcDate(2026, 4, 7, 10, 0)
        )
        _ = try await actor.upsertEntitlementCache(updated)
        #expect(try await actor.loadEntitlementCache() == updated)
    }
}

private func compositionWrite(itemId: String, createdAt: Date) -> LessonAttemptWrite {
    LessonAttemptWrite(
        courseId: "course_daily_ja_en",
        lessonId: "lesson_02_composition",
        itemId: itemId,
        contentRevision: 1,
        languagePairKey: "ja>en",
        skill: Skill.composition.rawValue,
        createdAt: createdAt,
        durationMs: 1_000,
        payloadSchemaVersion: 1,
        payloadJSON: Data("{}".utf8)
    )
}
