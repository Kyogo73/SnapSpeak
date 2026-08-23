import Foundation
import HabitKit
import SRSKit
import Testing

@Suite("ProgressSummarizer")
struct ProgressSummarizerTests {
    private var tokyo: Calendar { CalendarFixtures.tokyo() }

    private func summarize(
        activity: [Date] = [],
        samples: [ProgressSampleItem] = [],
        goal: Int = 10,
        now: Date,
        calendar: Calendar? = nil,
        grace: StreakGracePolicy = .bridgeSingleRestDay
    ) -> ProgressSummary {
        ProgressSummarizer.summarize(
            activity: activity,
            windowSamples: samples,
            goalItemsPerDay: goal,
            now: now,
            calendar: calendar ?? tokyo,
            grace: grace
        )
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int) -> Date {
        CalendarFixtures.date(year, month, day, hour, minute, calendar: tokyo)
    }

    private func sample(
        _ year: Int,
        _ month: Int,
        _ day: Int,
        _ hour: Int,
        _ minute: Int,
        mode: ProgressMode,
        rate: Double? = nil,
        passed: Bool? = nil
    ) -> ProgressSampleItem {
        ProgressSampleItem(
            createdAt: date(year, month, day, hour, minute),
            mode: mode,
            scriptMatchRate: rate,
            passed: passed
        )
    }

    @Test("空入力は 7 本の 0 バー・週計 0・平均 nil・streak 全ゼロ")
    func emptyInputIsZero() {
        let now = date(2026, 8, 21, 10, 0)
        let summary = summarize(now: now)

        #expect(summary.dailyBars.count == 7)
        #expect(summary.dailyBars.allSatisfy { $0.completedItems == 0 && $0.goalMet == false })
        #expect(summary.weekCompletedItems == 0)
        #expect(summary.shadowingAverageMatchRate == nil)
        #expect(summary.shadowingSampleCount == 0)
        #expect(summary.compositionPassRate == nil)
        #expect(summary.compositionScoredCount == 0)
        #expect(summary.streak.currentStreakDays == 0)
        #expect(summary.streak.longestStreakDays == 0)
        #expect(summary.streak.totalStudyDays == 0)
        #expect(summary.streak.studiedToday == false)
        #expect(summary.streak.isAtRisk == false)
        #expect(summary.streak.isOnLastGraceDay == false)

        let today = StudyDay.studyDay(of: now, calendar: tokyo)
        let oldest = tokyo.date(byAdding: .day, value: -6, to: today)
        #expect(summary.dailyBars.first?.dayStart == oldest)
        #expect(summary.dailyBars.last?.dayStart == today)
    }

    @Test("3 日分だけ学習するとバー 7 本中 3 本が非ゼロで古→新")
    func fillsZeroDaysAndOrdersOldestToNewest() {
        let now = date(2026, 8, 21, 10, 0)
        let samples = [
            sample(2026, 8, 19, 10, 0, mode: .shadowing, rate: 0.5),
            sample(2026, 8, 20, 10, 0, mode: .composition, passed: true),
            sample(2026, 8, 21, 10, 0, mode: .shadowing, rate: 0.9),
        ]
        let summary = summarize(samples: samples, now: now)

        #expect(summary.dailyBars.count == 7)
        let starts = summary.dailyBars.map(\.dayStart)
        #expect(starts == starts.sorted())
        let today = StudyDay.studyDay(of: now, calendar: tokyo)
        #expect(starts.last == today)
        #expect(starts.first == tokyo.date(byAdding: .day, value: -6, to: today))

        let nonzero = summary.dailyBars.filter { $0.completedItems > 0 }
        #expect(nonzero.count == 3)
        #expect(nonzero.map(\.completedItems) == [1, 1, 1])
        #expect(summary.dailyBars.suffix(3).allSatisfy { $0.completedItems == 1 })
        #expect(summary.dailyBars.prefix(4).allSatisfy { $0.completedItems == 0 })
    }

    @Test("03:59 の attempt は前学習日、04:00 は当学習日のバーに入る")
    func studyDayBoundary0359And0400() {
        let now = date(2026, 8, 21, 10, 0)
        let samples = [
            sample(2026, 8, 21, 3, 59, mode: .shadowing, rate: 0.4),
            sample(2026, 8, 21, 4, 0, mode: .shadowing, rate: 0.6),
        ]
        let summary = summarize(samples: samples, now: now)

        #expect(summary.dailyBars.count == 7)
        let previous = StudyDay.studyDay(of: date(2026, 8, 21, 3, 59), calendar: tokyo)
        let today = StudyDay.studyDay(of: now, calendar: tokyo)
        #expect(previous != today)

        let previousBar = summary.dailyBars.first { $0.dayStart == previous }
        let todayBar = summary.dailyBars.first { $0.dayStart == today }
        #expect(previousBar?.completedItems == 1)
        #expect(todayBar?.completedItems == 1)
        #expect(summary.dailyBars.filter { $0.completedItems > 0 }.count == 2)
    }

    @Test("goalMet は goal=3 で 3 件 true・2 件 false、goal=0 は常に false")
    func goalMetUsesCurrentGoalAndRejectsZero() {
        let now = date(2026, 8, 21, 10, 0)
        let samples = [
            sample(2026, 8, 20, 10, 0, mode: .shadowing, rate: 0.1),
            sample(2026, 8, 20, 11, 0, mode: .shadowing, rate: 0.2),
            sample(2026, 8, 21, 10, 0, mode: .composition, passed: true),
            sample(2026, 8, 21, 11, 0, mode: .composition, passed: true),
            sample(2026, 8, 21, 12, 0, mode: .composition, passed: false),
        ]

        let met = summarize(samples: samples, goal: 3, now: now)
        let yesterday = StudyDay.studyDay(of: date(2026, 8, 20, 10, 0), calendar: tokyo)
        let today = StudyDay.studyDay(of: now, calendar: tokyo)
        #expect(met.dailyBars.first { $0.dayStart == yesterday }?.goalMet == false)
        #expect(met.dailyBars.first { $0.dayStart == yesterday }?.completedItems == 2)
        #expect(met.dailyBars.first { $0.dayStart == today }?.goalMet == true)
        #expect(met.dailyBars.first { $0.dayStart == today }?.completedItems == 3)

        let zeroGoal = summarize(samples: samples, goal: 0, now: now)
        #expect(zeroGoal.dailyBars.allSatisfy { $0.goalMet == false })
        #expect(zeroGoal.dailyBars.contains { $0.completedItems == 3 })
    }

    @Test("shadowing 0.8 と 0.6 の平均は 0.7、composition の unscored は分母に入らない")
    func averagesIgnoreUnscoredComposition() {
        let now = date(2026, 8, 21, 10, 0)
        let samples = [
            sample(2026, 8, 21, 10, 0, mode: .shadowing, rate: 0.8),
            sample(2026, 8, 21, 11, 0, mode: .shadowing, rate: 0.6),
            sample(2026, 8, 21, 12, 0, mode: .shadowing),
            sample(2026, 8, 21, 13, 0, mode: .composition, passed: true),
            sample(2026, 8, 21, 14, 0, mode: .composition, passed: false),
            sample(2026, 8, 21, 15, 0, mode: .composition),
        ]
        let summary = summarize(samples: samples, now: now)

        #expect(summary.shadowingAverageMatchRate == 0.7)
        #expect(summary.shadowingSampleCount == 2)
        #expect(summary.compositionPassRate == 0.5)
        #expect(summary.compositionScoredCount == 2)
    }

    @Test("8 日前のサンプルはバーに入らないが shadowing 平均には入る")
    func olderThanSevenDaysExcludedFromBarsButIncludedInAverage() {
        let now = date(2026, 8, 21, 10, 0)
        let samples = [
            sample(2026, 8, 13, 10, 0, mode: .shadowing, rate: 1.0),
            sample(2026, 8, 21, 10, 0, mode: .shadowing, rate: 0.4),
        ]
        let summary = summarize(samples: samples, now: now)

        #expect(summary.dailyBars.allSatisfy { $0.completedItems == 0 || $0.dayStart == StudyDay.studyDay(of: now, calendar: tokyo) })
        #expect(summary.dailyBars.map(\.completedItems).reduce(0, +) == 1)
        #expect(summary.weekCompletedItems == 1)
        #expect(summary.shadowingAverageMatchRate == 0.7)
        #expect(summary.shadowingSampleCount == 2)

        let eightDaysAgo = StudyDay.studyDay(of: date(2026, 8, 13, 10, 0), calendar: tokyo)
        #expect(summary.dailyBars.contains { $0.dayStart == eightDaysAgo } == false)
    }

    @Test("streak は activity のみに依存し samples が空でも計算される")
    func streakDependsOnlyOnActivity() {
        let now = date(2026, 8, 21, 10, 0)
        let activity = [
            date(2026, 8, 19, 10, 0),
            date(2026, 8, 20, 10, 0),
            date(2026, 8, 21, 10, 0),
        ]
        let expected = StreakCalculator.snapshot(activity: activity, now: now, calendar: tokyo)
        let summary = summarize(activity: activity, samples: [], now: now)

        #expect(summary.streak == expected)
        #expect(summary.streak.currentStreakDays == 3)
        #expect(summary.streak.studiedToday == true)
        #expect(summary.dailyBars.allSatisfy { $0.completedItems == 0 })
        #expect(summary.weekCompletedItems == 0)
        #expect(summary.shadowingAverageMatchRate == nil)
    }

    @Test("weekCompletedItems はバーの completedItems 合計")
    func weekCompletedItemsEqualsBarSum() {
        let now = date(2026, 8, 21, 10, 0)
        let samples = [
            sample(2026, 8, 15, 10, 0, mode: .shadowing, rate: 0.1),
            sample(2026, 8, 17, 10, 0, mode: .composition, passed: true),
            sample(2026, 8, 17, 11, 0, mode: .composition, passed: true),
            sample(2026, 8, 21, 10, 0, mode: .shadowing, rate: 0.2),
            sample(2026, 8, 21, 11, 0, mode: .shadowing, rate: 0.3),
            sample(2026, 8, 21, 12, 0, mode: .composition, passed: false),
        ]
        let summary = summarize(samples: samples, now: now)
        let barSum = summary.dailyBars.map(\.completedItems).reduce(0, +)
        #expect(summary.weekCompletedItems == barSum)
        #expect(summary.weekCompletedItems == 6)
    }
}
