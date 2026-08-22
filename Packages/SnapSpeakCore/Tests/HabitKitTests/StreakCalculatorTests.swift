import Foundation
import HabitKit
import SRSKit
import Testing

@Suite("StreakCalculator")
struct StreakCalculatorTests {
    private var tokyo: Calendar { CalendarFixtures.tokyo() }

    private func snapshot(
        activity: [Date],
        now: Date,
        calendar: Calendar? = nil,
        grace: StreakGracePolicy = .bridgeSingleRestDay
    ) -> StreakSnapshot {
        StreakCalculator.snapshot(
            activity: activity,
            now: now,
            calendar: calendar ?? tokyo,
            grace: grace
        )
    }

    @Test("空 activity は全ゼロ")
    func emptyActivityIsZero() {
        let now = CalendarFixtures.date(2026, 8, 21, 10, 0, calendar: tokyo)
        let snap = snapshot(activity: [], now: now)
        #expect(snap.currentStreakDays == 0)
        #expect(snap.longestStreakDays == 0)
        #expect(snap.totalStudyDays == 0)
        #expect(snap.studiedToday == false)
        #expect(snap.isAtRisk == false)
        #expect(snap.isOnLastGraceDay == false)
    }

    @Test("今日 1 件のみ → current=1, studiedToday")
    func todayOnly() {
        let now = CalendarFixtures.date(2026, 8, 21, 10, 0, calendar: tokyo)
        let activity = [CalendarFixtures.date(2026, 8, 21, 9, 0, calendar: tokyo)]
        let snap = snapshot(activity: activity, now: now)
        #expect(snap.currentStreakDays == 1)
        #expect(snap.longestStreakDays == 1)
        #expect(snap.totalStudyDays == 1)
        #expect(snap.studiedToday == true)
        #expect(snap.isAtRisk == false)
        #expect(snap.isOnLastGraceDay == false)
    }

    @Test("03:59 完了が前学習日、04:00 が当学習日に入る")
    func studyDayBoundary0359And0400() {
        let now = CalendarFixtures.date(2026, 8, 21, 10, 0, calendar: tokyo)
        let before = CalendarFixtures.date(2026, 8, 21, 3, 59, calendar: tokyo)
        let onBoundary = CalendarFixtures.date(2026, 8, 21, 4, 0, calendar: tokyo)

        let onlyBefore = snapshot(activity: [before], now: now)
        #expect(onlyBefore.studiedToday == false)
        #expect(onlyBefore.currentStreakDays == 1)
        #expect(onlyBefore.isAtRisk == true)
        #expect(onlyBefore.totalStudyDays == 1)

        let onlyOn = snapshot(activity: [onBoundary], now: now)
        #expect(onlyOn.studiedToday == true)
        #expect(onlyOn.currentStreakDays == 1)
        #expect(onlyOn.totalStudyDays == 1)

        let both = snapshot(activity: [before, onBoundary], now: now)
        #expect(both.studiedToday == true)
        #expect(both.currentStreakDays == 2)
        #expect(both.totalStudyDays == 2)
    }

    @Test("連続 3 日 → current=3")
    func threeConsecutiveDays() {
        let now = CalendarFixtures.date(2026, 8, 21, 10, 0, calendar: tokyo)
        let activity = [
            CalendarFixtures.date(2026, 8, 19, 10, 0, calendar: tokyo),
            CalendarFixtures.date(2026, 8, 20, 10, 0, calendar: tokyo),
            CalendarFixtures.date(2026, 8, 21, 10, 0, calendar: tokyo),
        ]
        let snap = snapshot(activity: activity, now: now)
        #expect(snap.currentStreakDays == 3)
        #expect(snap.longestStreakDays == 3)
        #expect(snap.totalStudyDays == 3)
        #expect(snap.studiedToday == true)
    }

    @Test("今日未学習・昨日学習 → current 維持 + isAtRisk")
    func atRiskWhenYesterdayStudied() {
        let now = CalendarFixtures.date(2026, 8, 21, 10, 0, calendar: tokyo)
        let activity = [
            CalendarFixtures.date(2026, 8, 19, 10, 0, calendar: tokyo),
            CalendarFixtures.date(2026, 8, 20, 10, 0, calendar: tokyo),
        ]
        let snap = snapshot(activity: activity, now: now)
        #expect(snap.currentStreakDays == 2)
        #expect(snap.studiedToday == false)
        #expect(snap.isAtRisk == true)
        #expect(snap.isOnLastGraceDay == false)
    }

    @Test("昨日休み・一昨日学習 → 橋渡し維持 + isOnLastGraceDay")
    func lastGraceDayBridgesSingleRest() {
        let now = CalendarFixtures.date(2026, 8, 21, 10, 0, calendar: tokyo)
        let activity = [
            CalendarFixtures.date(2026, 8, 18, 10, 0, calendar: tokyo),
            CalendarFixtures.date(2026, 8, 19, 10, 0, calendar: tokyo),
        ]
        let snap = snapshot(activity: activity, now: now)
        #expect(snap.currentStreakDays == 2)
        #expect(snap.studiedToday == false)
        #expect(snap.isAtRisk == true)
        #expect(snap.isOnLastGraceDay == true)
    }

    @Test("昨日・一昨日休み → current=0")
    func twoRestDaysBreaksStreak() {
        let now = CalendarFixtures.date(2026, 8, 21, 10, 0, calendar: tokyo)
        let activity = [CalendarFixtures.date(2026, 8, 18, 10, 0, calendar: tokyo)]
        let snap = snapshot(activity: activity, now: now)
        #expect(snap.currentStreakDays == 0)
        #expect(snap.totalStudyDays == 1)
        #expect(snap.longestStreakDays == 1)
        #expect(snap.isAtRisk == false)
        #expect(snap.isOnLastGraceDay == false)
    }

    @Test(".none ポリシーでは 1 日休みで 0")
    func nonePolicyBreaksOnSingleRest() {
        let now = CalendarFixtures.date(2026, 8, 21, 10, 0, calendar: tokyo)
        let activity = [CalendarFixtures.date(2026, 8, 19, 10, 0, calendar: tokyo)]
        let snap = snapshot(activity: activity, now: now, grace: .none)
        #expect(snap.currentStreakDays == 0)
        #expect(snap.isOnLastGraceDay == false)
        #expect(snap.totalStudyDays == 1)
    }

    @Test("橋渡し日がカウントに入らない（学習 5 日 + 休み 2 回交互 → current=5）")
    func graceDaysAreNotCounted() {
        let now = CalendarFixtures.date(2026, 8, 16, 10, 0, calendar: tokyo)
        // S S R S S R S  → 5 study days, 2 rest days
        let activity = [
            CalendarFixtures.date(2026, 8, 10, 10, 0, calendar: tokyo),
            CalendarFixtures.date(2026, 8, 11, 10, 0, calendar: tokyo),
            CalendarFixtures.date(2026, 8, 13, 10, 0, calendar: tokyo),
            CalendarFixtures.date(2026, 8, 14, 10, 0, calendar: tokyo),
            CalendarFixtures.date(2026, 8, 16, 10, 0, calendar: tokyo),
        ]
        let snap = snapshot(activity: activity, now: now)
        #expect(snap.currentStreakDays == 5)
        #expect(snap.longestStreakDays == 5)
        #expect(snap.totalStudyDays == 5)
        #expect(snap.studiedToday == true)
    }

    @Test("同一学習日の複数完了が 1 日")
    func multipleCompletionsSameStudyDayCountAsOne() {
        let now = CalendarFixtures.date(2026, 8, 21, 22, 0, calendar: tokyo)
        let activity = [
            CalendarFixtures.date(2026, 8, 21, 5, 0, calendar: tokyo),
            CalendarFixtures.date(2026, 8, 21, 12, 0, calendar: tokyo),
            CalendarFixtures.date(2026, 8, 21, 20, 0, calendar: tokyo),
        ]
        let snap = snapshot(activity: activity, now: now)
        #expect(snap.currentStreakDays == 1)
        #expect(snap.totalStudyDays == 1)
        #expect(snap.studiedToday == true)
    }

    @Test("タイムゾーン変更してもイベント絶対時刻は不変・計算は破綻しない")
    func timezoneChangeReinterpretsWithoutMutatingEvents() {
        let tokyoCal = tokyo
        let la = CalendarFixtures.losAngeles()
        let instant = CalendarFixtures.date(2026, 8, 21, 3, 30, calendar: tokyoCal)
        let nowTokyo = CalendarFixtures.date(2026, 8, 21, 10, 0, calendar: tokyoCal)
        let activity = [instant]
        let before = instant.timeIntervalSince1970

        let tokyoSnap = snapshot(activity: activity, now: nowTokyo, calendar: tokyoCal)
        let laNow = nowTokyo
        let laSnap = snapshot(activity: activity, now: laNow, calendar: la)

        #expect(instant.timeIntervalSince1970 == before)
        #expect(tokyoSnap.totalStudyDays == 1)
        #expect(laSnap.totalStudyDays == 1)
        #expect(tokyoSnap.currentStreakDays >= 0)
        #expect(laSnap.currentStreakDays >= 0)
        #expect(tokyoSnap.longestStreakDays >= 0)
        #expect(laSnap.longestStreakDays >= 0)
        let tokyoDay = StudyDay.studyDay(of: instant, calendar: tokyoCal)
        let laDay = StudyDay.studyDay(of: instant, calendar: la)
        #expect(tokyoDay != laDay)
    }

    @Test("longest と total は独立")
    func longestAndTotalAreIndependent() {
        let now = CalendarFixtures.date(2026, 8, 21, 10, 0, calendar: tokyo)
        // 10-day streak, 2 rest, 3-day streak ending today
        var activity: [Date] = []
        for day in 1...10 {
            activity.append(CalendarFixtures.date(2026, 8, day, 10, 0, calendar: tokyo))
        }
        activity.append(CalendarFixtures.date(2026, 8, 19, 10, 0, calendar: tokyo))
        activity.append(CalendarFixtures.date(2026, 8, 20, 10, 0, calendar: tokyo))
        activity.append(CalendarFixtures.date(2026, 8, 21, 10, 0, calendar: tokyo))
        let snap = snapshot(activity: activity, now: now)
        #expect(snap.longestStreakDays == 10)
        #expect(snap.totalStudyDays == 13)
        #expect(snap.currentStreakDays == 3)
    }

    @Test("activity 順不同でも同じ結果")
    func unorderedActivityIsDeterministic() {
        let now = CalendarFixtures.date(2026, 8, 21, 10, 0, calendar: tokyo)
        let a = CalendarFixtures.date(2026, 8, 19, 10, 0, calendar: tokyo)
        let b = CalendarFixtures.date(2026, 8, 20, 10, 0, calendar: tokyo)
        let c = CalendarFixtures.date(2026, 8, 21, 10, 0, calendar: tokyo)
        let forward = snapshot(activity: [a, b, c], now: now)
        let reverse = snapshot(activity: [c, b, a], now: now)
        #expect(forward == reverse)
    }
}
