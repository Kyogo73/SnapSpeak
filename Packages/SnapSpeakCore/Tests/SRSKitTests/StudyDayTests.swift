import Foundation
import SRSKit
import Testing

private func calendar(timeZone: String) -> Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: timeZone)!
    calendar.locale = Locale(identifier: "en_US_POSIX")
    return calendar
}

@Test func studyDayBoundary0359IsPreviousDay() {
    let cal = calendar(timeZone: "Asia/Tokyo")
    // 2026-08-21 03:59 JST = 2026-08-20 18:59 UTC
    var components = DateComponents()
    components.year = 2026
    components.month = 8
    components.day = 21
    components.hour = 3
    components.minute = 59
    let date = cal.date(from: components)!
    let start = StudyDay.studyDay(of: date, calendar: cal)
    #expect(cal.component(.day, from: start) == 20)
    #expect(cal.component(.hour, from: start) == 4)
}

@Test func studyDayBoundary0400IsCurrentDay() {
    let cal = calendar(timeZone: "Asia/Tokyo")
    var components = DateComponents()
    components.year = 2026
    components.month = 8
    components.day = 21
    components.hour = 4
    components.minute = 0
    let date = cal.date(from: components)!
    let start = StudyDay.studyDay(of: date, calendar: cal)
    #expect(cal.component(.day, from: start) == 21)
    #expect(cal.component(.hour, from: start) == 4)
}

@Test func successDueAtAlignsToStudyDay0400() {
    let cal = calendar(timeZone: "Asia/Tokyo")
    var components = DateComponents()
    components.year = 2026
    components.month = 8
    components.day = 21
    components.hour = 10
    components.minute = 0
    let reviewedAt = cal.date(from: components)!
    let due = StudyDay.nextDueAt(intervalDays: 2, after: reviewedAt, calendar: cal)
    #expect(cal.component(.day, from: due) == 23)
    #expect(cal.component(.hour, from: due) == 4)
    #expect(cal.component(.minute, from: due) == 0)
}

@Test func failureScheduleIsTenMinutesPlusNextStudyDay() {
    let cal = calendar(timeZone: "Asia/Tokyo")
    var components = DateComponents()
    components.year = 2026
    components.month = 8
    components.day = 21
    components.hour = 10
    components.minute = 0
    let reviewedAt = cal.date(from: components)!
    let schedule = StudyDay.failureSchedule(after: reviewedAt, calendar: cal)
    #expect(schedule.retryNotBefore == reviewedAt.addingTimeInterval(10 * 60))
    #expect(cal.component(.day, from: schedule.nextStudyDayDueAt) == 22)
    #expect(cal.component(.hour, from: schedule.nextStudyDayDueAt) == 4)
}

@Test func timezoneChangeDoesNotRewritePastInstant() {
    let tokyo = calendar(timeZone: "Asia/Tokyo")
    let la = calendar(timeZone: "America/Los_Angeles")
    var components = DateComponents()
    components.year = 2026
    components.month = 8
    components.day = 21
    components.hour = 3
    components.minute = 30
    let instant = tokyo.date(from: components)!

    let tokyoDay = StudyDay.studyDay(of: instant, calendar: tokyo)
    let laDay = StudyDay.studyDay(of: instant, calendar: la)
    #expect(tokyoDay != laDay)
    #expect(instant.timeIntervalSince1970 == instant.timeIntervalSince1970)
}
