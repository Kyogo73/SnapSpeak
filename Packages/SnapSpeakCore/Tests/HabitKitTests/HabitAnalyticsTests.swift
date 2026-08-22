import Foundation
import HabitKit
import Testing

@Suite("HabitAnalytics")
struct HabitAnalyticsTests {
    private let day = Date(timeIntervalSince1970: 1_777_000_000)
    private let otherDay = Date(timeIntervalSince1970: 1_776_913_600)

    @Test("当日初の Attempt だけ streak_day_recorded を出す")
    func firstAttemptOfDayRecordsStreakOnce() {
        let first = HabitAnalytics.eventsAfterAttempt(
            studyDayStart: day,
            streakDaysAfter: 3,
            itemsTodayBefore: 0,
            itemsTodayAfter: 1,
            dailyGoal: 10,
            markers: HabitDayMarkers()
        )
        #expect(first.recordStreakDays == 3)
        #expect(first.metGoalItems == nil)
        #expect(first.nextMarkers.streakRecordedDayStart == day)

        let second = HabitAnalytics.eventsAfterAttempt(
            studyDayStart: day,
            streakDaysAfter: 3,
            itemsTodayBefore: 1,
            itemsTodayAfter: 2,
            dailyGoal: 10,
            markers: first.nextMarkers
        )
        #expect(second.recordStreakDays == nil)
        #expect(second.nextMarkers.streakRecordedDayStart == day)
    }

    @Test("ゴール到達の瞬間だけ goal_met を出し、同日再送しない")
    func goalMetFiresOnceWhenCrossing() {
        let before = HabitAnalytics.eventsAfterAttempt(
            studyDayStart: day,
            streakDaysAfter: 1,
            itemsTodayBefore: 8,
            itemsTodayAfter: 9,
            dailyGoal: 10,
            markers: HabitDayMarkers(streakRecordedDayStart: day)
        )
        #expect(before.metGoalItems == nil)

        let crossing = HabitAnalytics.eventsAfterAttempt(
            studyDayStart: day,
            streakDaysAfter: 1,
            itemsTodayBefore: 9,
            itemsTodayAfter: 10,
            dailyGoal: 10,
            markers: before.nextMarkers
        )
        #expect(crossing.metGoalItems == 10)

        let after = HabitAnalytics.eventsAfterAttempt(
            studyDayStart: day,
            streakDaysAfter: 1,
            itemsTodayBefore: 10,
            itemsTodayAfter: 11,
            dailyGoal: 10,
            markers: crossing.nextMarkers
        )
        #expect(after.metGoalItems == nil)
        #expect(after.nextMarkers.goalMetDayStart == day)
    }

    @Test("streak_broken は学習日あたり 1 回")
    func streakBrokenOncePerStudyDay() {
        #expect(
            HabitAnalytics.shouldRecordStreakBroken(
                streakDays: 0,
                lastKnownStreakDays: 5,
                studyDayStart: day,
                brokenRecordedDayStart: nil
            )
        )
        #expect(
            HabitAnalytics.shouldRecordStreakBroken(
                streakDays: 0,
                lastKnownStreakDays: 5,
                studyDayStart: day,
                brokenRecordedDayStart: day
            ) == false
        )
        #expect(
            HabitAnalytics.shouldRecordStreakBroken(
                streakDays: 0,
                lastKnownStreakDays: 5,
                studyDayStart: day,
                brokenRecordedDayStart: otherDay
            )
        )
        #expect(
            HabitAnalytics.shouldRecordStreakBroken(
                streakDays: 1,
                lastKnownStreakDays: 5,
                studyDayStart: day,
                brokenRecordedDayStart: nil
            ) == false
        )
    }
}
