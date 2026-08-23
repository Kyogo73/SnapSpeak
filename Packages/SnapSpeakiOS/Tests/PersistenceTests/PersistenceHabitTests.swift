import Foundation
import HabitKit
import Persistence
import SRSKit
import Testing

@Suite("Persistence habit fields & queue queries")
struct PersistenceHabitTests {
    @Test("UserSettings 新フィールドの既定値と roundtrip")
    func settingsHabitDefaultsAndRoundTrip() async throws {
        let actor = try makeActor()
        let loaded = try await actor.loadOrCreateSettings()
        #expect(loaded.dailyGoalItems == 10)
        #expect(loaded.reminderEnabled == false)
        #expect(loaded.reminderMinute == 0)
        #expect(loaded.onboardingCompletedAt == nil)
        #expect(loaded.lastKnownStreakDays == 0)
        #expect(loaded.habitStreakRecordedDayStart == nil)
        #expect(loaded.habitGoalMetDayStart == nil)
        #expect(loaded.habitBrokenRecordedDayStart == nil)
        #expect(loaded.recoveryDismissedFromStreak == 0)
        #expect(loaded.driveSessionMinutes == 10)
        #expect(loaded.drivePausePreset == "standard")
        #expect(loaded.driveShadowingRepeats == 2)

        var updated = loaded
        updated.dailyGoalItems = 20
        updated.reminderEnabled = true
        updated.reminderHour = 21
        updated.reminderMinute = 30
        let completedAt = Date(timeIntervalSince1970: 1_700_000_000)
        updated.onboardingCompletedAt = completedAt
        updated.lastKnownStreakDays = 7
        updated.driveSessionMinutes = 20
        updated.drivePausePreset = "long"
        updated.driveShadowingRepeats = 3
        let saved = try await actor.saveSettings(updated)
        #expect(saved.dailyGoalItems == 20)
        #expect(saved.reminderEnabled == true)
        #expect(saved.reminderHour == 21)
        #expect(saved.reminderMinute == 30)
        #expect(saved.onboardingCompletedAt == completedAt)
        #expect(saved.lastKnownStreakDays == 7)
        #expect(saved.driveSessionMinutes == 20)
        #expect(saved.drivePausePreset == "long")
        #expect(saved.driveShadowingRepeats == 3)

        let again = try await actor.loadOrCreateSettings()
        #expect(again == saved)
    }

    @Test("SRSCard.relearnGateAt が fold で書かれる")
    func foldWritesRelearnGateAt() async throws {
        let actor = try makeActor()
        let cardKey = CardKey(
            pairKey: "ja>en",
            courseId: "course_daily_ja_en",
            itemId: "crs_daily_ja_en_item_p_001",
            skill: .shadowing
        ).raw
        let reviewedAt = Date(timeIntervalSince1970: 1_700_000_400)

        let failEvent = ReviewEventDTO(
            id: UUID(),
            cardKey: cardKey,
            quality: ReviewQuality.fail.rawValue,
            reviewedAt: reviewedAt,
            clientSeq: 1,
            serverRevision: nil,
            contentRevision: 1
        )
        _ = try await actor.appendReviewEvent(
            ReviewEventWrite(
                event: failEvent,
                courseId: "course_daily_ja_en",
                itemId: "crs_daily_ja_en_item_p_001",
                skill: Skill.shadowing.rawValue
            )
        )
        let failed = try await actor.foldSRSCard(foldRequest(cardKey: cardKey, now: reviewedAt))
        #expect(failed.relearnGateAt != nil)
        #expect(failed.lastQuality == ReviewQuality.fail.rawValue)

        let passEvent = ReviewEventDTO(
            id: UUID(),
            cardKey: cardKey,
            quality: ReviewQuality.good.rawValue,
            reviewedAt: reviewedAt.addingTimeInterval(600),
            clientSeq: 2,
            serverRevision: nil,
            contentRevision: 1
        )
        _ = try await actor.appendReviewEvent(
            ReviewEventWrite(
                event: passEvent,
                courseId: "course_daily_ja_en",
                itemId: "crs_daily_ja_en_item_p_001",
                skill: Skill.shadowing.rawValue
            )
        )
        let passed = try await actor.foldSRSCard(
            foldRequest(cardKey: cardKey, now: reviewedAt.addingTimeInterval(600))
        )
        #expect(passed.relearnGateAt == nil)
        #expect(passed.lastQuality == ReviewQuality.good.rawValue)
    }

    @Test("dueCards(now:) のフィルタと昇順")
    func dueCardsFilterAndOrder() async throws {
        let actor = try makeActor()
        let earlyReview = Date(timeIntervalSince1970: 1_700_000_000)
        let lateReview = Date(timeIntervalSince1970: 1_700_100_000)
        _ = try await foldNewCard(
            actor: actor,
            itemId: "item_late",
            reviewedAt: lateReview,
            quality: .good
        )
        _ = try await foldNewCard(
            actor: actor,
            itemId: "item_early",
            reviewedAt: earlyReview,
            quality: .good
        )
        let now = Date(timeIntervalSince1970: 1_701_000_000)
        let due = try await actor.dueCards(now: now)
        #expect(due.map(\.itemId) == ["item_early", "item_late"])
        let beforeAny = try await actor.dueCards(now: Date(timeIntervalSince1970: 1_600_000_000))
        #expect(beforeAny.isEmpty)
    }

    @Test("失敗カードは dueAt が未来でも relearnGateAt 到達で dueCards に入る")
    func dueCardsIncludesGatedSameDayRetry() async throws {
        let actor = try makeActor()
        let reviewedAt = Date(timeIntervalSince1970: 1_700_000_400)
        let failed = try await foldNewCard(
            actor: actor,
            itemId: "failed_same_day",
            reviewedAt: reviewedAt,
            quality: .fail
        )
        #expect(failed.relearnGateAt != nil)
        #expect(failed.dueAt > reviewedAt.addingTimeInterval(10 * 60))
        let beforeGate = try await actor.dueCards(now: reviewedAt.addingTimeInterval(60))
        #expect(beforeGate.contains { $0.itemId == "failed_same_day" } == false)
        let afterGate = try await actor.dueCards(now: reviewedAt.addingTimeInterval(10 * 60))
        #expect(afterGate.contains { $0.itemId == "failed_same_day" })
    }

    @Test("appendAttemptEvaluatingHabit は当日初とゴール到達を一度だけ返す")
    func habitEventsFireOncePerStudyDay() async throws {
        let actor = try makeActor()
        var settings = try await actor.loadOrCreateSettings()
        settings.dailyGoalItems = 2
        _ = try await actor.saveSettings(settings)
        let now = Date(timeIntervalSince1970: 1_777_200_000)
        let first = try await actor.appendAttemptEvaluatingHabit(
            attemptWrite(itemId: "one", createdAt: now),
            timeZoneIdentifier: "UTC"
        )
        #expect(first.recordStreakDays != nil)
        #expect(first.metGoalItems == nil)
        let second = try await actor.appendAttemptEvaluatingHabit(
            attemptWrite(itemId: "two", createdAt: now.addingTimeInterval(10)),
            timeZoneIdentifier: "UTC"
        )
        #expect(second.recordStreakDays == nil)
        #expect(second.metGoalItems == 2)
        let third = try await actor.appendAttemptEvaluatingHabit(
            attemptWrite(itemId: "three", createdAt: now.addingTimeInterval(20)),
            timeZoneIdentifier: "UTC"
        )
        #expect(third.recordStreakDays == nil)
        #expect(third.metGoalItems == nil)
        let latest = try await actor.latestAttempt()
        #expect(latest?.itemId == "three")
    }

    @Test("updateLastKnownStreakDays は他設定を巻き戻さない")
    func lastKnownUpdateIsAtomic() async throws {
        let actor = try makeActor()
        var settings = try await actor.loadOrCreateSettings()
        settings.dailyGoalItems = 20
        settings.reminderEnabled = true
        _ = try await actor.saveSettings(settings)
        try await actor.updateLastKnownStreakDays(4)
        let loaded = try await actor.loadOrCreateSettings()
        #expect(loaded.lastKnownStreakDays == 4)
        #expect(loaded.dailyGoalItems == 20)
        #expect(loaded.reminderEnabled == true)
    }

    @Test("attemptCount は半開区間 [start, end)")
    func attemptCountHalfOpenInterval() async throws {
        let actor = try makeActor()
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let mid = Date(timeIntervalSince1970: 1_700_000_500)
        let end = Date(timeIntervalSince1970: 1_700_001_000)
        _ = try await actor.appendAttempt(attemptWrite(itemId: "a", createdAt: start))
        _ = try await actor.appendAttempt(attemptWrite(itemId: "b", createdAt: mid))
        _ = try await actor.appendAttempt(attemptWrite(itemId: "c", createdAt: end))
        let count = try await actor.attemptCount(from: start, to: end)
        #expect(count == 2)
    }

    @Test("attemptActivityDates と attemptedItemRefs の distinct")
    func activityDatesAndDistinctItemRefs() async throws {
        let actor = try makeActor()
        let first = Date(timeIntervalSince1970: 1_700_000_000)
        let second = Date(timeIntervalSince1970: 1_700_000_100)
        _ = try await actor.appendAttempt(attemptWrite(itemId: "item_a", createdAt: first))
        _ = try await actor.appendAttempt(attemptWrite(itemId: "item_a", createdAt: second))
        _ = try await actor.appendAttempt(attemptWrite(itemId: "item_b", createdAt: second))
        let dates = try await actor.attemptActivityDates()
        #expect(dates.sorted() == [first, second, second].sorted())
        let refs = try await actor.attemptedItemRefs()
        #expect(refs == [
            ItemRef(courseId: "course_daily_ja_en", itemId: "item_a"),
            ItemRef(courseId: "course_daily_ja_en", itemId: "item_b"),
        ])
    }

    @Test("appendAttemptEvaluatingHabit は Attempt と markers と lastKnown を同時に残す")
    func habitEvaluationPersistsAttemptMarkersAndStreakTogether() async throws {
        let actor = try makeActor()
        let createdAt = utcDate(2026, 4, 6, 10, 0)
        let result = try await actor.appendAttemptEvaluatingHabit(
            attemptWrite(itemId: "atomic", createdAt: createdAt),
            timeZoneIdentifier: "UTC"
        )
        #expect(result.recordStreakDays != nil)
        let stored = try await actor.fetchAttempt(id: result.attempt.id)
        #expect(stored?.itemId == "atomic")
        let settings = try await actor.loadOrCreateSettings()
        #expect(settings.habitStreakRecordedDayStart != nil)
        #expect(settings.lastKnownStreakDays == result.recordStreakDays)
    }

    @Test("同一 Attempt id の再評価はイベントを再発火せず件数も増えない")
    func habitEvaluationIsIdempotentForSameAttemptId() async throws {
        let actor = try makeActor()
        let createdAt = utcDate(2026, 4, 6, 10, 0)
        let write = attemptWrite(itemId: "same", createdAt: createdAt)
        let first = try await actor.appendAttemptEvaluatingHabit(
            write,
            timeZoneIdentifier: "UTC"
        )
        #expect(first.recordStreakDays != nil)
        let second = try await actor.appendAttemptEvaluatingHabit(
            write,
            timeZoneIdentifier: "UTC"
        )
        #expect(second.recordStreakDays == nil)
        #expect(second.attempt.id == first.attempt.id)
        let start = utcDate(2026, 4, 6, 4, 0)
        let end = utcDate(2026, 4, 7, 4, 0)
        #expect(try await actor.attemptCount(from: start, to: end) == 1)
    }

    @Test("学習日は write.createdAt。04:00 跨ぎは別学習日")
    func habitEvaluationUsesCreatedAtAcross0400() async throws {
        let actor = try makeActor()
        let before = utcDate(2026, 4, 6, 3, 59)
        let onBoundary = utcDate(2026, 4, 6, 4, 0)
        let first = try await actor.appendAttemptEvaluatingHabit(
            attemptWrite(itemId: "before_boundary", createdAt: before),
            timeZoneIdentifier: "UTC"
        )
        let second = try await actor.appendAttemptEvaluatingHabit(
            attemptWrite(itemId: "on_boundary", createdAt: onBoundary),
            timeZoneIdentifier: "UTC"
        )
        #expect(first.recordStreakDays != nil)
        #expect(second.recordStreakDays != nil)
    }

    @Test("createdAt が学習日を決める。同日の 2 件目は streak を再発火しない")
    func habitEvaluationUsesCreatedAtToDetermineStudyDay() async throws {
        let actor = try makeActor()
        let firstAt = utcDate(2026, 4, 6, 4, 0)
        let secondAt = utcDate(2026, 4, 6, 10, 0)
        let first = try await actor.appendAttemptEvaluatingHabit(
            attemptWrite(itemId: "morning", createdAt: firstAt),
            timeZoneIdentifier: "UTC"
        )
        let second = try await actor.appendAttemptEvaluatingHabit(
            attemptWrite(itemId: "afternoon", createdAt: secondAt),
            timeZoneIdentifier: "UTC"
        )
        #expect(first.recordStreakDays != nil)
        #expect(second.recordStreakDays == nil)
    }

    @Test("attempts(from:to:) は範囲外除外・半開区間・createdAt 昇順")
    func attemptsHalfOpenIntervalAndAscendingCreatedAt() async throws {
        let actor = try makeActor()
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let midEarly = Date(timeIntervalSince1970: 1_700_000_400)
        let midLate = Date(timeIntervalSince1970: 1_700_000_800)
        let end = Date(timeIntervalSince1970: 1_700_001_000)
        let before = Date(timeIntervalSince1970: 1_699_999_000)
        let after = Date(timeIntervalSince1970: 1_700_002_000)
        _ = try await actor.appendAttempt(attemptWrite(itemId: "late", createdAt: midLate))
        _ = try await actor.appendAttempt(attemptWrite(itemId: "before", createdAt: before))
        _ = try await actor.appendAttempt(attemptWrite(itemId: "end", createdAt: end))
        _ = try await actor.appendAttempt(attemptWrite(itemId: "start", createdAt: start))
        _ = try await actor.appendAttempt(attemptWrite(itemId: "after", createdAt: after))
        _ = try await actor.appendAttempt(attemptWrite(itemId: "early", createdAt: midEarly))
        let found = try await actor.attempts(from: start, to: end)
        #expect(found.map(\.itemId) == ["start", "early", "late"])
        #expect(found.map(\.createdAt) == [start, midEarly, midLate])
    }
}
