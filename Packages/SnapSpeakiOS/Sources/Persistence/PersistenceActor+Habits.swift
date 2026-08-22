import Foundation
import HabitKit
import SRSKit
import SwiftData

// MARK: - 継続（習慣）と今日の学習キュー

extension PersistenceActor {
    public func updateLastKnownStreakDays(_ days: Int) throws {
        let model = try requireSettings()
        model.lastKnownStreakDays = days
        try saveOrRollback()
    }

    public func updateHabitMarkers(_ markers: HabitDayMarkers) throws {
        let model = try requireSettings()
        model.habitStreakRecordedDayStart = markers.streakRecordedDayStart
        model.habitGoalMetDayStart = markers.goalMetDayStart
        model.habitBrokenRecordedDayStart = markers.brokenRecordedDayStart
        try saveOrRollback()
    }

    public func markRecoveryDismissed(fromStreak: Int) throws {
        let model = try requireSettings()
        model.recoveryDismissedFromStreak = fromStreak
        try saveOrRollback()
    }

    public func recordLastOpenedLesson(
        courseId: String,
        lessonId: String,
        itemId: String,
        mode: String
    ) throws {
        let model = try requireSettings()
        model.lastOpenedCourseId = courseId
        model.lastOpenedLessonId = lessonId
        model.lastOpenedItemId = itemId
        model.lastOpenedMode = mode
        try saveOrRollback()
    }

    public func latestAttempt() throws -> LessonAttemptDTO? {
        var descriptor = FetchDescriptor<LessonAttempt>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first.map(PersistenceMapping.attemptDTO)
    }

    /// Attempt・markers・lastKnownStreakDays を単一 `save()` で追記する。
    /// 学習日は `write.createdAt` で判定する。
    /// save 失敗時は `saveOrRollback` で Attempt・markers・lastKnown が揃って巻き戻る。
    public func appendAttemptEvaluatingHabit(
        _ write: LessonAttemptWrite,
        timeZoneIdentifier: String = TimeZone.autoupdatingCurrent.identifier
    ) throws -> AttemptHabitResult {
        let settings = try loadOrCreateSettings()
        if let existing = try fetchAttempt(id: write.id) {
            return AttemptHabitResult(
                attempt: existing,
                recordStreakDays: nil,
                metGoalItems: nil,
                dailyGoalItems: settings.dailyGoalItems
            )
        }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: timeZoneIdentifier)
            ?? TimeZone(secondsFromGMT: 0)
            ?? TimeZone.current
        let studyAt = write.createdAt
        let dayStart = StudyDay.studyDay(of: studyAt, calendar: calendar)
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart
        let itemsBefore = try attemptCount(from: dayStart, to: dayEnd)
        let model = makeAttemptModel(write)
        modelContext.insert(model)
        let itemsAfter = itemsBefore + 1
        var activity = try attemptActivityDates()
        if !activity.contains(studyAt) {
            activity.append(studyAt)
        }
        let streak = StreakCalculator.snapshot(activity: activity, now: studyAt, calendar: calendar)
        let events = HabitAnalytics.eventsAfterAttempt(
            studyDayStart: dayStart,
            streakDaysAfter: streak.currentStreakDays,
            itemsTodayBefore: itemsBefore,
            itemsTodayAfter: itemsAfter,
            dailyGoal: settings.dailyGoalItems,
            markers: settings.habitMarkers
        )
        try applyHabitFieldsInMemory(
            markers: events.nextMarkers,
            lastKnownStreakDays: streak.currentStreakDays
        )
        try saveOrRollback()
        return AttemptHabitResult(
            attempt: PersistenceMapping.attemptDTO(model),
            recordStreakDays: events.recordStreakDays,
            metGoalItems: events.metGoalItems,
            dailyGoalItems: settings.dailyGoalItems
        )
    }

    func applyHabitFieldsInMemory(markers: HabitDayMarkers, lastKnownStreakDays: Int) throws {
        let model = try requireSettings()
        model.habitStreakRecordedDayStart = markers.streakRecordedDayStart
        model.habitGoalMetDayStart = markers.goalMetDayStart
        model.habitBrokenRecordedDayStart = markers.brokenRecordedDayStart
        model.lastKnownStreakDays = lastKnownStreakDays
    }

    /// `dueAt <= now` に加え、失敗カードは `relearnGateAt <= now` でも候補に含める。
    /// optional の `#Predicate` 比較を避け、件数規模が小さい前提でメモリ上で合流する。
    public func dueCards(now: Date) throws -> [SRSCardDTO] {
        let cards = try modelContext.fetch(
            FetchDescriptor<SRSCard>(sortBy: [SortDescriptor(\.dueAt)])
        )
        return cards
            .filter { card in
                if card.dueAt <= now { return true }
                if let gate = card.relearnGateAt { return gate <= now }
                return false
            }
            .map(PersistenceMapping.cardDTO)
    }

    /// 全 LessonAttempt の createdAt（ストリーク計算の入力。propertiesToFetch で軽量化）。
    public func attemptActivityDates() throws -> [Date] {
        var descriptor = FetchDescriptor<LessonAttempt>()
        descriptor.propertiesToFetch = [\.createdAt]
        return try modelContext.fetch(descriptor).map(\.createdAt)
    }

    /// 期間内の LessonAttempt 件数（今日のゴール進捗。半開区間 [start, end)）。
    public func attemptCount(from start: Date, to end: Date) throws -> Int {
        let startDate = start
        let endDate = end
        let descriptor = FetchDescriptor<LessonAttempt>(
            predicate: #Predicate { $0.createdAt >= startDate && $0.createdAt < endDate }
        )
        return try modelContext.fetchCount(descriptor)
    }

    /// 試行が 1 件以上ある (courseId, itemId) の集合（次レッスン選定の入力）。
    public func attemptedItemRefs() throws -> Set<ItemRef> {
        let descriptor = FetchDescriptor<LessonAttempt>()
        let attempts = try modelContext.fetch(descriptor)
        return Set(attempts.map { ItemRef(courseId: $0.courseId, itemId: $0.itemId) })
    }
}
