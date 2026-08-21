import Foundation
import SRSKit
import Testing

private func tokyoCalendar() -> Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Asia/Tokyo")!
    calendar.locale = Locale(identifier: "en_US_POSIX")
    return calendar
}

@Test func easinessGoldenSequence() {
    let calendar = tokyoCalendar()
    let t0 = Date(timeIntervalSince1970: 1_700_000_000)
    var state = SRSState.initial(now: t0)

    state = SM2.apply(state: state, quality: .easy, reviewedAt: t0, calendar: calendar)
    #expect(abs(state.easiness - 2.6) < 0.000_001)
    #expect(state.intervalDays == 1)
    #expect(state.repetitions == 1)

    state = SM2.apply(state: state, quality: .easy, reviewedAt: t0, calendar: calendar)
    #expect(abs(state.easiness - 2.7) < 0.000_001)
    #expect(state.intervalDays == 6)
    #expect(state.repetitions == 2)

    state = SM2.apply(state: state, quality: .easy, reviewedAt: t0, calendar: calendar)
    #expect(abs(state.easiness - 2.8) < 0.000_001)
    #expect(state.intervalDays == Int((6.0 * 2.8).rounded()))
    #expect(state.repetitions == 3)
}

@Test func qualityThreeDecreasesEF() {
    let calendar = tokyoCalendar()
    let t0 = Date(timeIntervalSince1970: 1_700_000_000)
    var state = SRSState.initial(now: t0)
    state = SM2.apply(state: state, quality: .pass, reviewedAt: t0, calendar: calendar)
    #expect(abs(state.easiness - 2.36) < 0.000_001)
}

@Test func qualityZeroResetsRepetitions() {
    let calendar = tokyoCalendar()
    let t0 = Date(timeIntervalSince1970: 1_700_000_000)
    var state = SRSState.initial(now: t0)
    state = SM2.apply(state: state, quality: .easy, reviewedAt: t0, calendar: calendar)
    state = SM2.apply(state: state, quality: .blackout, reviewedAt: t0, calendar: calendar)
    #expect(state.repetitions == 0)
    #expect(abs(state.easiness - 1.8) < 0.000_001)
}

@Test func failureBlocksReviewForTenMinutesThenAllowsSameDayRelearn() {
    let calendar = tokyoCalendar()
    var components = DateComponents()
    components.year = 2026
    components.month = 8
    components.day = 21
    components.hour = 10
    components.minute = 0
    let reviewedAt = calendar.date(from: components)!
    var state = SRSState.initial(now: reviewedAt)
    state = SM2.apply(state: state, quality: .fail, reviewedAt: reviewedAt, calendar: calendar)

    let schedule = StudyDay.failureSchedule(after: reviewedAt, calendar: calendar)
    #expect(state.relearnGateAt == schedule.retryNotBefore)
    #expect(state.dueAt == schedule.nextStudyDayDueAt)
    #expect(calendar.component(.day, from: state.dueAt) == 22)
    #expect(calendar.component(.hour, from: state.dueAt) == 4)

    let oneMinuteLater = reviewedAt.addingTimeInterval(60)
    #expect(!state.isPastRelearnGate(at: oneMinuteLater))
    #expect(!state.isDue(at: oneMinuteLater))
    #expect(!state.canRelearnSameDay(at: oneMinuteLater))

    let tenMinutesLater = reviewedAt.addingTimeInterval(10 * 60)
    #expect(state.isPastRelearnGate(at: tenMinutesLater))
    #expect(state.canRelearnSameDay(at: tenMinutesLater))
    #expect(!state.isDue(at: tenMinutesLater))

    #expect(state.isDue(at: schedule.nextStudyDayDueAt))
}

@Test func successDueAtIsNextStudyDay0400AndClearsGate() {
    let calendar = tokyoCalendar()
    var components = DateComponents()
    components.year = 2026
    components.month = 8
    components.day = 21
    components.hour = 10
    components.minute = 0
    let reviewedAt = calendar.date(from: components)!
    var state = SRSState.initial(now: reviewedAt)
    state = SM2.apply(state: state, quality: .good, reviewedAt: reviewedAt, calendar: calendar)

    #expect(state.relearnGateAt == nil)
    #expect(state.isPastRelearnGate(at: reviewedAt))
    #expect(calendar.component(.day, from: state.dueAt) == 22)
    #expect(calendar.component(.hour, from: state.dueAt) == 4)
    #expect(calendar.component(.minute, from: state.dueAt) == 0)
    #expect(!state.isDue(at: reviewedAt))
    #expect(state.isDue(at: state.dueAt))
}

@Test func easinessFloorIs1_3() {
    var easiness = 1.4
    for _ in 0..<20 {
        easiness = SM2.updatedEasiness(easiness, quality: 0)
        if easiness < SRSState.minimumEasiness {
            easiness = SRSState.minimumEasiness
        }
    }
    #expect(easiness == 1.3)
}

@Test func intervalProgression1Then6ThenRound() {
    let calendar = tokyoCalendar()
    let t0 = Date(timeIntervalSince1970: 1_700_000_000)
    var state = SRSState.initial(now: t0)
    state = SM2.apply(state: state, quality: .good, reviewedAt: t0, calendar: calendar)
    #expect(state.intervalDays == 1)
    state = SM2.apply(state: state, quality: .good, reviewedAt: t0, calendar: calendar)
    #expect(state.intervalDays == 6)
    let expected = Int((6.0 * state.easiness).rounded())
    state = SM2.apply(state: state, quality: .good, reviewedAt: t0, calendar: calendar)
    #expect(state.intervalDays == expected)
}
