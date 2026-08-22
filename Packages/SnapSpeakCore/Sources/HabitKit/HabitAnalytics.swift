import Foundation

/// 学習日単位の分析発火済みマーカー。
public struct HabitDayMarkers: Sendable, Equatable {
    public var streakRecordedDayStart: Date?
    public var goalMetDayStart: Date?
    public var brokenRecordedDayStart: Date?

    public init(
        streakRecordedDayStart: Date? = nil,
        goalMetDayStart: Date? = nil,
        brokenRecordedDayStart: Date? = nil
    ) {
        self.streakRecordedDayStart = streakRecordedDayStart
        self.goalMetDayStart = goalMetDayStart
        self.brokenRecordedDayStart = brokenRecordedDayStart
    }
}

/// Attempt 追記後に発火すべき習慣イベント。
public struct HabitAttemptEvents: Sendable, Equatable {
    public var recordStreakDays: Int?
    public var metGoalItems: Int?
    public var nextMarkers: HabitDayMarkers

    public init(recordStreakDays: Int? = nil, metGoalItems: Int? = nil, nextMarkers: HabitDayMarkers) {
        self.recordStreakDays = recordStreakDays
        self.metGoalItems = metGoalItems
        self.nextMarkers = nextMarkers
    }
}

/// 当日初の `streak_day_recorded` / `goal_met` と、切れ観測の一回性。
public enum HabitAnalytics: Sendable {
    /// Attempt 追記直後。`itemsTodayAfter` は当該学習日の Attempt 件数（今回を含む）。
    public static func eventsAfterAttempt(
        studyDayStart: Date,
        streakDaysAfter: Int,
        itemsTodayBefore: Int,
        itemsTodayAfter: Int,
        dailyGoal: Int,
        markers: HabitDayMarkers
    ) -> HabitAttemptEvents {
        var next = markers
        var recordStreakDays: Int?
        var metGoalItems: Int?

        let firstOfDay = itemsTodayBefore == 0 && itemsTodayAfter >= 1
        if firstOfDay, next.streakRecordedDayStart != studyDayStart {
            recordStreakDays = streakDaysAfter
            next.streakRecordedDayStart = studyDayStart
        }

        let crossedGoal = itemsTodayBefore < dailyGoal && itemsTodayAfter >= dailyGoal
        if crossedGoal, next.goalMetDayStart != studyDayStart {
            metGoalItems = itemsTodayAfter
            next.goalMetDayStart = studyDayStart
        }

        return HabitAttemptEvents(
            recordStreakDays: recordStreakDays,
            metGoalItems: metGoalItems,
            nextMarkers: next
        )
    }

    /// 切れを初めて観測した学習日だけ `streak_broken` を出す。
    public static func shouldRecordStreakBroken(
        streakDays: Int,
        lastKnownStreakDays: Int,
        studyDayStart: Date,
        brokenRecordedDayStart: Date?
    ) -> Bool {
        streakDays == 0
            && lastKnownStreakDays > 0
            && brokenRecordedDayStart != studyDayStart
    }
}
