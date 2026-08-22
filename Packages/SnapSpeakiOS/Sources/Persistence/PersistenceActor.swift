import ContentCore
import Foundation
import HabitKit
import SRSKit
import SwiftData

/// Owns the SwiftData `ModelContext`. Callers receive Sendable DTOs only.
@ModelActor
public actor PersistenceActor {
    private let engine = SRSEngine()

    nonisolated public static func makeContainer(inMemory: Bool = false) throws -> ModelContainer {
        let schema = Schema(versionedSchema: SnapSpeakSchemaV1.self)
        let configuration: ModelConfiguration
        if inMemory {
            configuration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: true
            )
        } else {
            configuration = ModelConfiguration(schema: schema)
        }
        return try ModelContainer(
            for: schema,
            migrationPlan: SnapSpeakMigrationPlan.self,
            configurations: [configuration]
        )
    }

    public func appendAttempt(_ write: LessonAttemptWrite) throws -> LessonAttemptDTO {
        let existing = try fetchAttempt(id: write.id)
        if let existing { return existing }
        let model = LessonAttempt(
            id: write.id,
            courseId: write.courseId,
            lessonId: write.lessonId,
            itemId: write.itemId,
            contentRevision: write.contentRevision,
            languagePairKey: write.languagePairKey,
            skill: write.skill,
            createdAt: write.createdAt,
            durationMs: write.durationMs,
            payloadSchemaVersion: write.payloadSchemaVersion,
            payloadJSON: write.payloadJSON
        )
        modelContext.insert(model)
        try modelContext.save()
        return PersistenceMapping.attemptDTO(model)
    }

    public func fetchAttempt(id: UUID) throws -> LessonAttemptDTO? {
        let target = id
        var descriptor = FetchDescriptor<LessonAttempt>(
            predicate: #Predicate { $0.id == target }
        )
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first.map(PersistenceMapping.attemptDTO)
    }

    public func appendReviewEvent(_ write: ReviewEventWrite) throws -> ReviewEventDTO {
        let target = write.event.id
        var existingDescriptor = FetchDescriptor<ReviewEvent>(
            predicate: #Predicate { $0.id == target }
        )
        existingDescriptor.fetchLimit = 1
        if let existing = try modelContext.fetch(existingDescriptor).first {
            return PersistenceMapping.reviewDTO(existing)
        }
        let event = write.event
        let model = ReviewEvent(
            id: event.id,
            cardKey: event.cardKey,
            courseId: write.courseId,
            itemId: write.itemId,
            contentRevision: event.contentRevision,
            skill: write.skill,
            quality: event.quality,
            reviewedAt: event.reviewedAt,
            clientSeq: event.clientSeq,
            serverRevision: event.serverRevision,
            payloadSchemaVersion: write.payloadSchemaVersion,
            payloadJSON: write.payloadJSON
        )
        modelContext.insert(model)
        try modelContext.save()
        return PersistenceMapping.reviewDTO(model)
    }

    public func reviewEvents(forCardKey cardKey: String) throws -> [ReviewEventDTO] {
        let key = cardKey
        let descriptor = FetchDescriptor<ReviewEvent>(
            predicate: #Predicate { $0.cardKey == key }
        )
        return try modelContext.fetch(descriptor).map(PersistenceMapping.reviewDTO)
    }

    /// Rebuilds the derived `SRSCard` from the append-only event stream. Never LWW-merges.
    public func foldSRSCard(_ request: SRSCardFoldRequest) throws -> SRSCardDTO {
        let rawEvents = try reviewEvents(forCardKey: request.cardKey)
        let events = Self.eventsForFold(
            rawEvents,
            inheritSRS: request.inheritSRS,
            contentRevision: request.contentRevision
        )
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: request.timeZoneIdentifier)
            ?? TimeZone(secondsFromGMT: 0)
            ?? TimeZone(identifier: "GMT")
            ?? TimeZone.current
        let state = engine.fold(
            events: events,
            now: request.now,
            calendar: calendar,
            dayBoundaryHour: request.dayBoundaryHour
        )
        let highestRevision = events.compactMap(\.serverRevision).max()
        let key = request.cardKey
        var descriptor = FetchDescriptor<SRSCard>(
            predicate: #Predicate { $0.cardKey == key }
        )
        descriptor.fetchLimit = 1
        let model: SRSCard
        if let existing = try modelContext.fetch(descriptor).first {
            model = existing
        } else {
            model = SRSCard(
                cardKey: request.cardKey,
                sourceLanguage: request.sourceLanguage,
                targetLanguage: request.targetLanguage,
                courseId: request.courseId,
                itemId: request.itemId,
                skill: request.skill,
                contentRevision: request.contentRevision,
                inheritSRS: request.inheritSRS,
                easiness: state.easiness,
                intervalDays: state.intervalDays,
                repetitions: state.repetitions,
                dueAt: state.dueAt,
                relearnGateAt: state.relearnGateAt,
                lastReviewedAt: state.lastReviewedAt,
                lastQuality: state.lastQuality,
                foldedThroughRevision: highestRevision
            )
            modelContext.insert(model)
        }
        model.sourceLanguage = request.sourceLanguage
        model.targetLanguage = request.targetLanguage
        model.courseId = request.courseId
        model.itemId = request.itemId
        model.skill = request.skill
        model.contentRevision = state.contentRevision
        model.inheritSRS = request.inheritSRS
        model.easiness = state.easiness
        model.intervalDays = state.intervalDays
        model.repetitions = state.repetitions
        model.dueAt = state.dueAt
        model.relearnGateAt = state.relearnGateAt
        model.lastReviewedAt = state.lastReviewedAt
        model.lastQuality = state.lastQuality
        model.foldedThroughRevision = highestRevision
        try modelContext.save()
        return PersistenceMapping.cardDTO(model)
    }

    /// Compatible releases (`inheritSRS == true`) fold the full cardKey stream.
    /// Incompatible revisions keep old events on disk but start a fresh SM-2 fold.
    static func eventsForFold(
        _ events: [ReviewEventDTO],
        inheritSRS: Bool,
        contentRevision: Int
    ) -> [ReviewEventDTO] {
        if inheritSRS { return events }
        return events.filter { $0.contentRevision == contentRevision }
    }

    public func fetchSRSCard(cardKey: String) throws -> SRSCardDTO? {
        let key = cardKey
        var descriptor = FetchDescriptor<SRSCard>(
            predicate: #Predicate { $0.cardKey == key }
        )
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first.map(PersistenceMapping.cardDTO)
    }

    public func nextClientSeq() throws -> Int64 {
        let descriptor = FetchDescriptor<ReviewEvent>()
        let events = try modelContext.fetch(descriptor)
        return (events.map(\.clientSeq).max() ?? 0) + 1
    }

    public func loadOrCreateSettings() throws -> UserSettingsDTO {
        var descriptor = FetchDescriptor<UserSettings>()
        descriptor.fetchLimit = 1
        if let existing = try modelContext.fetch(descriptor).first {
            return PersistenceMapping.settingsDTO(existing)
        }
        let defaults = UserSettingsDTO.phase1Default
        let model = UserSettings(
            sourceLanguage: defaults.sourceLanguage,
            targetLanguage: defaults.targetLanguage,
            captionsEnabled: defaults.captionsEnabled,
            defaultRate: defaults.defaultRate,
            reminderHour: defaults.reminderHour,
            reminderMinute: defaults.reminderMinute,
            reminderEnabled: defaults.reminderEnabled,
            dailyGoalItems: defaults.dailyGoalItems,
            onboardingCompletedAt: defaults.onboardingCompletedAt,
            lastKnownStreakDays: defaults.lastKnownStreakDays,
            habitStreakRecordedDayStart: defaults.habitStreakRecordedDayStart,
            habitGoalMetDayStart: defaults.habitGoalMetDayStart,
            habitBrokenRecordedDayStart: defaults.habitBrokenRecordedDayStart,
            recoveryDismissedFromStreak: defaults.recoveryDismissedFromStreak,
            lastOpenedCourseId: defaults.lastOpenedCourseId,
            lastOpenedLessonId: defaults.lastOpenedLessonId,
            lastOpenedItemId: defaults.lastOpenedItemId,
            lastOpenedMode: defaults.lastOpenedMode,
            fieldRevisionsJSON: defaults.fieldRevisionsJSON,
            deletedAt: defaults.deletedAt
        )
        modelContext.insert(model)
        try modelContext.save()
        return PersistenceMapping.settingsDTO(model)
    }

    public func saveSettings(_ dto: UserSettingsDTO) throws -> UserSettingsDTO {
        var descriptor = FetchDescriptor<UserSettings>()
        descriptor.fetchLimit = 1
        let model: UserSettings
        if let existing = try modelContext.fetch(descriptor).first {
            model = existing
        } else {
            model = UserSettings(
                sourceLanguage: dto.sourceLanguage,
                targetLanguage: dto.targetLanguage,
                captionsEnabled: dto.captionsEnabled,
                defaultRate: dto.defaultRate,
                reminderHour: dto.reminderHour,
                reminderMinute: dto.reminderMinute,
                reminderEnabled: dto.reminderEnabled,
                dailyGoalItems: dto.dailyGoalItems,
                onboardingCompletedAt: dto.onboardingCompletedAt,
                lastKnownStreakDays: dto.lastKnownStreakDays,
                habitStreakRecordedDayStart: dto.habitStreakRecordedDayStart,
                habitGoalMetDayStart: dto.habitGoalMetDayStart,
                habitBrokenRecordedDayStart: dto.habitBrokenRecordedDayStart,
                recoveryDismissedFromStreak: dto.recoveryDismissedFromStreak,
                lastOpenedCourseId: dto.lastOpenedCourseId,
                lastOpenedLessonId: dto.lastOpenedLessonId,
                lastOpenedItemId: dto.lastOpenedItemId,
                lastOpenedMode: dto.lastOpenedMode,
                fieldRevisionsJSON: dto.fieldRevisionsJSON,
                deletedAt: dto.deletedAt
            )
            modelContext.insert(model)
        }
        model.sourceLanguage = dto.sourceLanguage
        model.targetLanguage = dto.targetLanguage
        model.captionsEnabled = dto.captionsEnabled
        model.defaultRate = dto.defaultRate
        model.reminderHour = dto.reminderHour
        model.reminderMinute = dto.reminderMinute
        model.reminderEnabled = dto.reminderEnabled
        model.dailyGoalItems = dto.dailyGoalItems
        model.onboardingCompletedAt = dto.onboardingCompletedAt
        model.lastKnownStreakDays = dto.lastKnownStreakDays
        model.habitStreakRecordedDayStart = dto.habitStreakRecordedDayStart
        model.habitGoalMetDayStart = dto.habitGoalMetDayStart
        model.habitBrokenRecordedDayStart = dto.habitBrokenRecordedDayStart
        model.recoveryDismissedFromStreak = dto.recoveryDismissedFromStreak
        model.lastOpenedCourseId = dto.lastOpenedCourseId
        model.lastOpenedLessonId = dto.lastOpenedLessonId
        model.lastOpenedItemId = dto.lastOpenedItemId
        model.lastOpenedMode = dto.lastOpenedMode
        model.fieldRevisionsJSON = dto.fieldRevisionsJSON
        model.deletedAt = dto.deletedAt
        try modelContext.save()
        return PersistenceMapping.settingsDTO(model)
    }

    /// `lastKnownStreakDays` だけを原子的に更新する（他設定の巻き戻しを防ぐ）。
    public func updateLastKnownStreakDays(_ days: Int) throws {
        let model = try requireSettings()
        model.lastKnownStreakDays = days
        try modelContext.save()
    }

    public func updateHabitMarkers(_ markers: HabitDayMarkers) throws {
        let model = try requireSettings()
        model.habitStreakRecordedDayStart = markers.streakRecordedDayStart
        model.habitGoalMetDayStart = markers.goalMetDayStart
        model.habitBrokenRecordedDayStart = markers.brokenRecordedDayStart
        try modelContext.save()
    }

    public func markRecoveryDismissed(fromStreak: Int) throws {
        let model = try requireSettings()
        model.recoveryDismissedFromStreak = fromStreak
        try modelContext.save()
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
        try modelContext.save()
    }

    public func latestAttempt() throws -> LessonAttemptDTO? {
        var descriptor = FetchDescriptor<LessonAttempt>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first.map(PersistenceMapping.attemptDTO)
    }

    /// Attempt を追記し、学習日前後から当日初の習慣イベントを原子的に判定する。
    public func appendAttemptEvaluatingHabit(
        _ write: LessonAttemptWrite,
        now: Date = Date(),
        timeZoneIdentifier: String = TimeZone.autoupdatingCurrent.identifier
    ) throws -> AttemptHabitResult {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: timeZoneIdentifier)
            ?? TimeZone(secondsFromGMT: 0)
            ?? TimeZone.current
        let dayStart = StudyDay.studyDay(of: now, calendar: calendar)
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart
        let itemsBefore = try attemptCount(from: dayStart, to: dayEnd)
        let attempt = try appendAttempt(write)
        let itemsAfter = try attemptCount(from: dayStart, to: dayEnd)
        let activity = try attemptActivityDates()
        let streak = StreakCalculator.snapshot(activity: activity, now: now, calendar: calendar)
        let settings = try loadOrCreateSettings()
        let events = HabitAnalytics.eventsAfterAttempt(
            studyDayStart: dayStart,
            streakDaysAfter: streak.currentStreakDays,
            itemsTodayBefore: itemsBefore,
            itemsTodayAfter: itemsAfter,
            dailyGoal: settings.dailyGoalItems,
            markers: settings.habitMarkers
        )
        try updateHabitMarkers(events.nextMarkers)
        try updateLastKnownStreakDays(streak.currentStreakDays)
        return AttemptHabitResult(
            attempt: attempt,
            recordStreakDays: events.recordStreakDays,
            metGoalItems: events.metGoalItems,
            dailyGoalItems: settings.dailyGoalItems
        )
    }

    private func requireSettings() throws -> UserSettings {
        _ = try loadOrCreateSettings()
        var descriptor = FetchDescriptor<UserSettings>()
        descriptor.fetchLimit = 1
        guard let model = try modelContext.fetch(descriptor).first else {
            throw PersistenceError.missingSettings
        }
        return model
    }

    public func upsertDownloadedCourse(_ dto: DownloadedCourseDTO) throws -> DownloadedCourseDTO {
        guard KnownContentSchemaVersions.contains(dto.schemaVersion) else {
            throw PersistenceError.unknownContentSchema(dto.schemaVersion)
        }
        let courseId = dto.courseId
        var descriptor = FetchDescriptor<DownloadedCourse>(
            predicate: #Predicate { $0.courseId == courseId }
        )
        descriptor.fetchLimit = 1
        let model: DownloadedCourse
        if let existing = try modelContext.fetch(descriptor).first {
            model = existing
        } else {
            model = DownloadedCourse(
                courseId: dto.courseId,
                sourceLanguage: dto.sourceLanguage,
                targetLanguage: dto.targetLanguage,
                revision: dto.revision,
                schemaVersion: dto.schemaVersion,
                releaseId: dto.releaseId,
                localPath: dto.localPath,
                downloadedAt: dto.downloadedAt,
                bytes: dto.bytes,
                checksumSha256: dto.checksumSha256
            )
            modelContext.insert(model)
        }
        model.sourceLanguage = dto.sourceLanguage
        model.targetLanguage = dto.targetLanguage
        model.revision = dto.revision
        model.schemaVersion = dto.schemaVersion
        model.releaseId = dto.releaseId
        model.localPath = dto.localPath
        model.downloadedAt = dto.downloadedAt
        model.bytes = dto.bytes
        model.checksumSha256 = dto.checksumSha256
        try modelContext.save()
        return PersistenceMapping.downloadedDTO(model)
    }

    public func downloadedCourses() throws -> [DownloadedCourseDTO] {
        try modelContext.fetch(FetchDescriptor<DownloadedCourse>()).map(PersistenceMapping.downloadedDTO)
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

    public func deleteDownloadedCourse(courseId: String) throws {
        let target = courseId
        let descriptor = FetchDescriptor<DownloadedCourse>(
            predicate: #Predicate { $0.courseId == target }
        )
        for model in try modelContext.fetch(descriptor) {
            modelContext.delete(model)
        }
        try modelContext.save()
    }
}

public enum PersistenceError: Error, Sendable, Equatable {
    case unknownContentSchema(Int)
    case missingSettings
}
