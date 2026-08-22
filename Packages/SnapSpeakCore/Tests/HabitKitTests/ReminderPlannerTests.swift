import Foundation
import HabitKit
import Testing

@Suite("ReminderPlanner")
struct ReminderPlannerTests {
    private var tokyo: Calendar { CalendarFixtures.tokyo() }
    private var la: Calendar { CalendarFixtures.losAngeles() }

    private func streak(
        current: Int,
        studiedToday: Bool,
        isAtRisk: Bool,
        isOnLastGraceDay: Bool = false
    ) -> StreakSnapshot {
        StreakSnapshot(
            currentStreakDays: current,
            longestStreakDays: max(current, 1),
            totalStudyDays: max(current, 1),
            studiedToday: studiedToday,
            isAtRisk: isAtRisk,
            isOnLastGraceDay: isOnLastGraceDay
        )
    }

    @Test("disabled → []")
    func disabledReturnsEmpty() {
        let now = CalendarFixtures.date(2026, 8, 21, 10, 0, calendar: tokyo)
        let plan = ReminderPlanner.plan(
            settings: ReminderSettings(isEnabled: false, hour: 21, minute: 0),
            streak: streak(current: 1, studiedToday: false, isAtRisk: true),
            now: now,
            calendar: tokyo
        )
        #expect(plan.isEmpty)
    }

    @Test("hour=24 等の範囲外 → []")
    func outOfRangeTimeReturnsEmpty() {
        let now = CalendarFixtures.date(2026, 8, 21, 10, 0, calendar: tokyo)
        let hour = ReminderPlanner.plan(
            settings: ReminderSettings(isEnabled: true, hour: 24, minute: 0),
            streak: streak(current: 0, studiedToday: false, isAtRisk: false),
            now: now,
            calendar: tokyo
        )
        let minute = ReminderPlanner.plan(
            settings: ReminderSettings(isEnabled: true, hour: 21, minute: 60),
            streak: streak(current: 0, studiedToday: false, isAtRisk: false),
            now: now,
            calendar: tokyo
        )
        #expect(hour.isEmpty)
        #expect(minute.isEmpty)
    }

    @Test("今日の時刻が未来かつ未学習・streak>0 なら kind=streakRisk")
    func todayFutureUnstudiedWithStreakIsRisk() {
        let now = CalendarFixtures.date(2026, 8, 21, 10, 0, calendar: tokyo)
        let plan = ReminderPlanner.plan(
            settings: ReminderSettings(isEnabled: true, hour: 21, minute: 0),
            streak: streak(current: 5, studiedToday: false, isAtRisk: true),
            now: now,
            calendar: tokyo
        )
        #expect(plan.isEmpty == false)
        #expect(plan[0].kind == .streakRisk)
        #expect(plan[0].streakDays == 5)
        #expect(plan[0].id == "reminder-2026-08-21")
    }

    @Test("streak=0 なら daily")
    func zeroStreakIsDaily() {
        let now = CalendarFixtures.date(2026, 8, 21, 10, 0, calendar: tokyo)
        let plan = ReminderPlanner.plan(
            settings: ReminderSettings(isEnabled: true, hour: 21, minute: 0),
            streak: streak(current: 0, studiedToday: false, isAtRisk: false),
            now: now,
            calendar: tokyo
        )
        #expect(plan[0].kind == .daily)
    }

    @Test("今日学習済み → 今日分スキップ、翌日から horizon 分")
    func studiedTodaySkipsCurrentStudyDay() {
        let now = CalendarFixtures.date(2026, 8, 21, 10, 0, calendar: tokyo)
        let plan = ReminderPlanner.plan(
            settings: ReminderSettings(isEnabled: true, hour: 21, minute: 0),
            streak: streak(current: 3, studiedToday: true, isAtRisk: false),
            now: now,
            calendar: tokyo,
            horizonDays: 3
        )
        #expect(plan.count == 2)
        #expect(plan.map(\.id) == ["reminder-2026-08-22", "reminder-2026-08-23"])
        #expect(plan.allSatisfy { $0.kind == .daily })
    }

    @Test("今日の時刻が過去 → 明日から")
    func pastTodaysTimeStartsTomorrow() {
        let now = CalendarFixtures.date(2026, 8, 21, 22, 0, calendar: tokyo)
        let plan = ReminderPlanner.plan(
            settings: ReminderSettings(isEnabled: true, hour: 21, minute: 0),
            streak: streak(current: 2, studiedToday: false, isAtRisk: true),
            now: now,
            calendar: tokyo,
            horizonDays: 3
        )
        #expect(plan.count == 2)
        #expect(plan[0].id == "reminder-2026-08-22")
        #expect(plan[0].kind == .daily)
    }

    @Test("horizonDays=3 で件数上限")
    func horizonCapsCount() {
        let now = CalendarFixtures.date(2026, 8, 21, 10, 0, calendar: tokyo)
        let plan = ReminderPlanner.plan(
            settings: ReminderSettings(isEnabled: true, hour: 21, minute: 0),
            streak: streak(current: 0, studiedToday: false, isAtRisk: false),
            now: now,
            calendar: tokyo,
            horizonDays: 3
        )
        #expect(plan.count == 3)
        #expect(Set(plan.map(\.id)).count == 3)
    }

    @Test("id が reminder-yyyy-MM-dd 形式で日毎に一意")
    func identifierFormatIsUniquePerDay() {
        let now = CalendarFixtures.date(2026, 8, 21, 10, 0, calendar: tokyo)
        let plan = ReminderPlanner.plan(
            settings: ReminderSettings(isEnabled: true, hour: 21, minute: 30),
            streak: streak(current: 0, studiedToday: false, isAtRisk: false),
            now: now,
            calendar: tokyo
        )
        for item in plan {
            #expect(item.id.hasPrefix("reminder-"))
            let suffix = String(item.id.dropFirst("reminder-".count))
            #expect(suffix.wholeMatch(of: /\d{4}-\d{2}-\d{2}/) != nil)
        }
        #expect(Set(plan.map(\.id)).count == plan.count)
    }

    @Test("深夜設定の学習日跨ぎ: 0:30 に学習済みなら 1:00 はスキップ")
    func lateNightReminderSkippedWhenCurrentStudyDayDone() {
        let now = CalendarFixtures.date(2026, 8, 21, 0, 30, calendar: tokyo)
        let plan = ReminderPlanner.plan(
            settings: ReminderSettings(isEnabled: true, hour: 1, minute: 0),
            streak: streak(current: 4, studiedToday: true, isAtRisk: false),
            now: now,
            calendar: tokyo,
            horizonDays: 3
        )
        #expect(plan.contains { $0.id == "reminder-2026-08-21" } == false)
        #expect(plan.map(\.id) == ["reminder-2026-08-22", "reminder-2026-08-23"])
    }

    @Test("学習日境界 04:00 を DST 切替日でも解決できる")
    func dstStudyDayBoundaryAtFourAM() {
        let calendar = la
        // US Pacific spring-forward 2026-03-08 02:00 → 03:00。04:00 は存在する。
        let now = CalendarFixtures.date(2026, 3, 8, 3, 30, calendar: calendar)
        let plan = ReminderPlanner.plan(
            settings: ReminderSettings(isEnabled: true, hour: 4, minute: 0),
            streak: streak(current: 2, studiedToday: false, isAtRisk: true),
            now: now,
            calendar: calendar,
            horizonDays: 2
        )
        #expect(plan.isEmpty == false)
        #expect(plan[0].id == "reminder-2026-03-08")
        #expect(calendarHour(plan[0].fireAt, calendar: calendar) == 4)
    }

    @Test("存在しない壁時計時刻の日はスキップし残りを組む")
    func missingWallClockTimeSkipsThatDay() {
        let calendar = la
        // 2026-03-08 02:30 は spring-forward で存在しない。
        let now = CalendarFixtures.date(2026, 3, 7, 10, 0, calendar: calendar)
        let plan = ReminderPlanner.plan(
            settings: ReminderSettings(isEnabled: true, hour: 2, minute: 30),
            streak: streak(current: 0, studiedToday: false, isAtRisk: false),
            now: now,
            calendar: calendar,
            horizonDays: 3
        )
        #expect(plan.contains { $0.id == "reminder-2026-03-08" } == false)
        #expect(plan.allSatisfy { $0.id != "reminder-2026-03-08" })
        #expect(Set(plan.map(\.id)).count == plan.count)
    }

    @Test("重複する壁時計時刻でも 1 日 1 件")
    func duplicateWallClockTimeEmitsAtMostOne() {
        let calendar = CalendarFixtures.london()
        // 2026-10-25 01:30 は秋の巻き戻しで 2 回存在する。
        let now = CalendarFixtures.date(2026, 10, 24, 10, 0, calendar: calendar)
        let plan = ReminderPlanner.plan(
            settings: ReminderSettings(isEnabled: true, hour: 1, minute: 30),
            streak: streak(current: 0, studiedToday: false, isAtRisk: false),
            now: now,
            calendar: calendar,
            horizonDays: 3
        )
        let fallBack = plan.filter { $0.id == "reminder-2026-10-25" }
        #expect(fallBack.count <= 1)
        #expect(Set(plan.map(\.id)).count == plan.count)
    }

    @Test("DST 切替日でも 1 日 1 件")
    func dstTransitionAtMostOnePerCalendarDay() {
        // US Pacific spring-forward 2026-03-08 02:00 → 03:00
        let now = CalendarFixtures.date(2026, 3, 7, 10, 0, calendar: la)
        let plan = ReminderPlanner.plan(
            settings: ReminderSettings(isEnabled: true, hour: 21, minute: 0),
            streak: streak(current: 1, studiedToday: false, isAtRisk: true),
            now: now,
            calendar: la,
            horizonDays: 3
        )
        #expect(plan.count <= 3)
        let days = plan.map(\.id)
        #expect(Set(days).count == days.count)
        #expect(plan.allSatisfy { calendarHour($0.fireAt, calendar: la) == 21 })
    }

    private func calendarHour(_ date: Date, calendar: Calendar) -> Int {
        calendar.component(.hour, from: date)
    }
}
