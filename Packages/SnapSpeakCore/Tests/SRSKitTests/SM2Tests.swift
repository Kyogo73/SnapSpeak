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
