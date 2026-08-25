import Foundation
import SRSKit
import SwiftData

extension PersistenceActor {
    /// Composition attempts in the study day containing `now` (04:00 boundary, half-open).
    public func compositionAttemptCount(
        now: Date,
        timeZoneIdentifier: String = TimeZone.autoupdatingCurrent.identifier
    ) throws -> Int {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: timeZoneIdentifier)
            ?? TimeZone(secondsFromGMT: 0)
            ?? TimeZone.current
        let dayStart = StudyDay.studyDay(of: now, calendar: calendar)
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart
        return try compositionAttemptCount(from: dayStart, to: dayEnd)
    }

    /// Composition attempts in `[start, end)`. Shadowing is excluded.
    public func compositionAttemptCount(from start: Date, to end: Date) throws -> Int {
        let startDate = start
        let endDate = end
        let skill = Skill.composition.rawValue
        let descriptor = FetchDescriptor<LessonAttempt>(
            predicate: #Predicate { attempt in
                attempt.createdAt >= startDate
                    && attempt.createdAt < endDate
                    && attempt.skill == skill
            }
        )
        return try modelContext.fetchCount(descriptor)
    }

    public func loadEntitlementCache() throws -> EntitlementCacheDTO? {
        var descriptor = FetchDescriptor<EntitlementCache>()
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first.map(PersistenceMapping.entitlementDTO)
    }

    public func upsertEntitlementCache(_ dto: EntitlementCacheDTO) throws -> EntitlementCacheDTO {
        var descriptor = FetchDescriptor<EntitlementCache>()
        descriptor.fetchLimit = 1
        let model: EntitlementCache
        if let existing = try modelContext.fetch(descriptor).first {
            model = existing
        } else {
            model = EntitlementCache(
                isPro: dto.isPro,
                expirationDate: dto.expirationDate,
                billingRetryExpired: dto.billingRetryExpired,
                inGracePeriod: dto.inGracePeriod,
                updatedAt: dto.updatedAt
            )
            modelContext.insert(model)
        }
        model.isPro = dto.isPro
        model.expirationDate = dto.expirationDate
        model.billingRetryExpired = dto.billingRetryExpired
        model.inGracePeriod = dto.inGracePeriod
        model.updatedAt = dto.updatedAt
        try saveOrRollback()
        return PersistenceMapping.entitlementDTO(model)
    }
}
