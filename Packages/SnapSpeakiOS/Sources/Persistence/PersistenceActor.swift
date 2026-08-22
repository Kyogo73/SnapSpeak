import Foundation
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

    /// save 失敗時に未保存変更を巻き戻してから rethrow する（部分状態を残さない）。
    func saveOrRollback() throws {
        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            throw error
        }
    }

    /// テスト用。未保存 insert を rollback すると 0 件になることを固定する。
    public func countAttemptsAfterUnsavedInsertRollback(_ write: LessonAttemptWrite) throws -> Int {
        let model = makeAttemptModel(write)
        modelContext.insert(model)
        modelContext.rollback()
        return try modelContext.fetch(FetchDescriptor<LessonAttempt>()).count
    }

    public func appendAttempt(_ write: LessonAttemptWrite) throws -> LessonAttemptDTO {
        if let existing = try fetchAttempt(id: write.id) { return existing }
        let model = makeAttemptModel(write)
        modelContext.insert(model)
        try saveOrRollback()
        return PersistenceMapping.attemptDTO(model)
    }

    func makeAttemptModel(_ write: LessonAttemptWrite) -> LessonAttempt {
        LessonAttempt(
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
        try saveOrRollback()
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
        try saveOrRollback()
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
}

public enum PersistenceError: Error, Sendable, Equatable {
    case unknownContentSchema(Int)
    case missingSettings
}
