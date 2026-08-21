import Foundation
import SRSKit
import Testing

private func tokyoCalendar() -> Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Asia/Tokyo")!
    return calendar
}

@Test func emptyEventsYieldInitialState() {
    let engine = SRSEngine()
    let now = Date(timeIntervalSince1970: 1_700_000_000)
    let state = engine.fold(events: [], now: now, calendar: tokyoCalendar(), dayBoundaryHour: 4)
    #expect(state.easiness == 2.5)
    #expect(state.repetitions == 0)
    #expect(state.lastReviewedAt == nil)
    #expect(state.dueAt == now)
}

@Test func foldOrdersServerRevisionThenUnsyncedClientSeq() {
    let engine = SRSEngine()
    let now = Date(timeIntervalSince1970: 1_700_000_000)
    let t1 = now.addingTimeInterval(10)
    let t2 = now.addingTimeInterval(20)
    let t3 = now.addingTimeInterval(30)
    let idA = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    let idB = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
    let idC = UUID(uuidString: "00000000-0000-0000-0000-000000000003")!

    let unsyncedLate = ReviewEventDTO(
        id: idC,
        cardKey: "ja>en:c:i:composition",
        quality: 5,
        reviewedAt: t3,
        clientSeq: 2,
        serverRevision: nil,
        contentRevision: 1
    )
    let unsyncedEarly = ReviewEventDTO(
        id: idB,
        cardKey: "ja>en:c:i:composition",
        quality: 5,
        reviewedAt: t2,
        clientSeq: 1,
        serverRevision: nil,
        contentRevision: 1
    )
    let synced = ReviewEventDTO(
        id: idA,
        cardKey: "ja>en:c:i:composition",
        quality: 5,
        reviewedAt: t1,
        clientSeq: 99,
        serverRevision: 1,
        contentRevision: 1
    )

    let state = engine.fold(
        events: [unsyncedLate, synced, unsyncedEarly],
        now: now,
        calendar: tokyoCalendar(),
        dayBoundaryHour: 4
    )
    #expect(state.repetitions == 3)
    #expect(state.lastQuality == 5)
}

@Test func duplicateUUIDIsIdempotent() {
    let engine = SRSEngine()
    let now = Date(timeIntervalSince1970: 1_700_000_000)
    let id = UUID(uuidString: "00000000-0000-0000-0000-00000000000a")!
    let event = ReviewEventDTO(
        id: id,
        cardKey: "ja>en:c:i:composition",
        quality: 5,
        reviewedAt: now,
        clientSeq: 1,
        serverRevision: 1,
        contentRevision: 1
    )
    let once = engine.fold(events: [event], now: now, calendar: tokyoCalendar(), dayBoundaryHour: 4)
    let twice = engine.fold(events: [event, event], now: now, calendar: tokyoCalendar(), dayBoundaryHour: 4)
    #expect(once == twice)
    #expect(once.repetitions == 1)
}

@Test func foldFailureKeepsGateAndNextStudyDayDue() {
    let engine = SRSEngine()
    let calendar = tokyoCalendar()
    var components = DateComponents()
    components.year = 2026
    components.month = 8
    components.day = 21
    components.hour = 10
    components.minute = 0
    let reviewedAt = calendar.date(from: components)!
    let event = ReviewEventDTO(
        id: UUID(),
        cardKey: "ja>en:c:i:shadowing",
        quality: ReviewQuality.fail.rawValue,
        reviewedAt: reviewedAt,
        clientSeq: 1,
        serverRevision: nil,
        contentRevision: 1
    )
    let state = engine.fold(events: [event], now: reviewedAt, calendar: calendar, dayBoundaryHour: 4)
    let schedule = StudyDay.failureSchedule(after: reviewedAt, calendar: calendar)
    #expect(state.relearnGateAt == schedule.retryNotBefore)
    #expect(state.dueAt == schedule.nextStudyDayDueAt)
    #expect(!state.isDue(at: reviewedAt.addingTimeInterval(10 * 60)))
    #expect(state.canRelearnSameDay(at: reviewedAt.addingTimeInterval(10 * 60)))
}
