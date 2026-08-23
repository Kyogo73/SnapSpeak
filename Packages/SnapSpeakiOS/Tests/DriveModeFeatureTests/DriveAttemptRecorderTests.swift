import Analytics
import DriveKit
import DriveModeFeature
import Foundation
import Persistence
import SRSKit
import Testing

@Suite("DriveAttemptRecorder")
struct DriveAttemptRecorderTests {
    @Test("未採点 Attempt を書き、ReviewEvent は増やさず dueAt を動かさない")
    func recordsUnscoredAttemptWithoutSRS() async throws {
        let persistence = try makeDrivePersistence()
        let analytics = RecordingAnalytics()
        let recorder = DriveAttemptRecorder(persistence: persistence, analytics: analytics)
        let now = Date(timeIntervalSince1970: 1_777_200_000)
        let card = try await foldDriveCard(
            actor: persistence,
            courseId: "course_a",
            itemId: "item_ok",
            reviewedAt: now
        )
        let dueBefore = card.dueAt
        let eventsBefore = try await persistence.reviewEvents(forCardKey: card.cardKey)

        let result = try await recorder.record(
            item: driveItem(id: "item_ok", skill: .shadowing),
            lookup: driveLookup(),
            passIndex: 0,
            usedTTSFallback: true,
            elapsedMs: 4_200,
            settings: DriveScriptSettings.standard
        )

        #expect(result.attempt.payloadSchemaVersion == DriveAttemptPayload.shadowingSchemaVersion)
        #expect(result.attempt.skill == Skill.shadowing.rawValue)
        #expect(result.attempt.durationMs == 4_200)
        let payload = try JSONDecoder().decode(DriveAttemptPayload.self, from: result.attempt.payloadJSON)
        #expect(payload.context == "drive")
        #expect(payload.passIndex == 0)
        #expect(payload.usedTTSFallback == true)
        #expect(payload.repeats == 2)
        #expect(payload.speakPauseMs == nil)

        let eventsAfter = try await persistence.reviewEvents(forCardKey: card.cardKey)
        #expect(eventsAfter.count == eventsBefore.count)
        let cardAfter = try await persistence.fetchSRSCard(cardKey: card.cardKey)
        #expect(cardAfter?.dueAt == dueBefore)
    }

    @Test("composition payload は外側バージョン 3")
    func compositionPayloadUsesSchema3() async throws {
        let persistence = try makeDrivePersistence()
        let recorder = DriveAttemptRecorder(persistence: persistence, analytics: RecordingAnalytics())
        let result = try await recorder.record(
            item: driveItem(id: "item_c", skill: .composition, l1: "こんにちは", l2: "Hello"),
            lookup: driveLookup(lessonId: "lesson_c"),
            passIndex: 1,
            usedTTSFallback: false,
            elapsedMs: 3_000,
            settings: DriveScriptSettings.standard
        )
        #expect(result.attempt.payloadSchemaVersion == DriveAttemptPayload.compositionSchemaVersion)
        let payload = try JSONDecoder().decode(DriveAttemptPayload.self, from: result.attempt.payloadJSON)
        #expect(payload.context == "drive")
        #expect(payload.passIndex == 1)
        #expect(payload.repeats == nil)
        #expect(payload.speakPauseMs != nil)
    }

    @Test("createdAt は呼び出し側のイベント時刻を保存する")
    func recordsProvidedCreatedAt() async throws {
        let persistence = try makeDrivePersistence()
        let recorder = DriveAttemptRecorder(persistence: persistence, analytics: RecordingAnalytics())
        let createdAt = Date(timeIntervalSince1970: 1_700_000_123)
        let result = try await recorder.record(
            item: driveItem(id: "item_ok", skill: .shadowing),
            lookup: driveLookup(),
            passIndex: 0,
            usedTTSFallback: false,
            elapsedMs: 1_000,
            createdAt: createdAt,
            settings: DriveScriptSettings.standard
        )
        #expect(result.attempt.createdAt == createdAt)
        let stored = try await persistence.latestAttempt()
        #expect(stored?.createdAt == createdAt)
    }

    @Test("habit イベントは学習日あたり一度だけ")
    func habitEventsFireOnce() async throws {
        let persistence = try makeDrivePersistence()
        var settings = try await persistence.loadOrCreateSettings()
        settings.dailyGoalItems = 1
        _ = try await persistence.saveSettings(settings)
        let analytics = RecordingAnalytics()
        let recorder = DriveAttemptRecorder(persistence: persistence, analytics: analytics)

        let first = try await recorder.record(
            item: driveItem(id: "one", skill: .shadowing),
            lookup: driveLookup(),
            passIndex: 0,
            usedTTSFallback: false,
            elapsedMs: 1_000,
            settings: DriveScriptSettings.standard
        )
        #expect(first.recordStreakDays != nil)
        #expect(first.metGoalItems == 1)

        let second = try await recorder.record(
            item: driveItem(id: "two", skill: .shadowing),
            lookup: driveLookup(),
            passIndex: 0,
            usedTTSFallback: false,
            elapsedMs: 1_000,
            settings: DriveScriptSettings.standard
        )
        #expect(second.recordStreakDays == nil)
        #expect(second.metGoalItems == nil)

        let streaks = analytics.events.filter {
            if case .streakDayRecorded = $0 { return true }
            return false
        }
        let goals = analytics.events.filter {
            if case .goalMet = $0 { return true }
            return false
        }
        #expect(streaks.count == 1)
        #expect(goals.count == 1)
    }
}

private func makeDrivePersistence() throws -> PersistenceActor {
    let container = try PersistenceActor.makeContainer(inMemory: true)
    return PersistenceActor(modelContainer: container)
}

private func driveItem(
    id: String,
    skill: Skill,
    l1: String? = nil,
    l2: String = "Hello"
) -> DriveItem {
    DriveItem(
        courseId: "course_a",
        itemId: id,
        skill: skill,
        origin: .due,
        l1Text: l1,
        l2Text: l2,
        l1LanguageTag: "ja",
        l2LanguageTag: "en",
        audioRelativePath: "audio/\(id).m4a",
        audioDurationMs: 1_000
    )
}

private func driveLookup(lessonId: String = "lesson_1") -> DrivePlanResolver.Lookup {
    DrivePlanResolver.Lookup(
        lessonId: lessonId,
        contentRevision: 1,
        languagePairKey: "ja>en",
        courseTitle: "日常英会話",
        directory: URL(fileURLWithPath: "/tmp")
    )
}

private func foldDriveCard(
    actor: PersistenceActor,
    courseId: String,
    itemId: String,
    reviewedAt: Date
) async throws -> SRSCardDTO {
    let cardKey = CardKey(
        pairKey: "ja>en",
        courseId: courseId,
        itemId: itemId,
        skill: .shadowing
    ).raw
    let event = ReviewEventDTO(
        id: UUID(),
        cardKey: cardKey,
        quality: ReviewQuality.good.rawValue,
        reviewedAt: reviewedAt,
        clientSeq: 1,
        serverRevision: nil,
        contentRevision: 1
    )
    _ = try await actor.appendReviewEvent(
        ReviewEventWrite(
            event: event,
            courseId: courseId,
            itemId: itemId,
            skill: Skill.shadowing.rawValue
        )
    )
    return try await actor.foldSRSCard(
        SRSCardFoldRequest(
            cardKey: cardKey,
            sourceLanguage: "ja",
            targetLanguage: "en",
            courseId: courseId,
            itemId: itemId,
            skill: Skill.shadowing.rawValue,
            contentRevision: 1,
            inheritSRS: true,
            now: reviewedAt,
            timeZoneIdentifier: "UTC",
            dayBoundaryHour: 4
        )
    )
}

final class RecordingAnalytics: AnalyticsClient, @unchecked Sendable {
    private(set) var events: [AnalyticsEvent] = []

    func track(_ event: AnalyticsEvent) {
        events.append(event)
    }
}
