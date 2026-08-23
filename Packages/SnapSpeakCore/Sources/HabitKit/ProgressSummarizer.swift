import Foundation
import SRSKit

public enum ProgressMode: String, Sendable, Equatable {
    case shadowing
    case composition
}

/// ダッシュボード集計の入力サンプル（payload デコード済みの最小値）。
public struct ProgressSampleItem: Sendable, Equatable {
    public var createdAt: Date
    public var mode: ProgressMode
    /// shadowing のみ。
    public var scriptMatchRate: Double?
    /// composition のみ。unscored は nil。
    public var passed: Bool?

    public init(
        createdAt: Date,
        mode: ProgressMode,
        scriptMatchRate: Double? = nil,
        passed: Bool? = nil
    ) {
        self.createdAt = createdAt
        self.mode = mode
        self.scriptMatchRate = scriptMatchRate
        self.passed = passed
    }
}

/// 1 学習日の完了数バー（直近 7 学習日の 1 本）。
public struct DailyProgressBar: Sendable, Equatable {
    /// 学習日開始（04:00 境界）。
    public var dayStart: Date
    public var completedItems: Int
    /// 現在の `goalItemsPerDay` 基準。
    public var goalMet: Bool

    public init(dayStart: Date, completedItems: Int, goalMet: Bool) {
        self.dayStart = dayStart
        self.completedItems = completedItems
        self.goalMet = goalMet
    }
}

/// 進捗ダッシュボード用の集計結果。正本は LessonAttempt 列であり、本値は保存しない。
public struct ProgressSummary: Sendable, Equatable {
    public var streak: StreakSnapshot
    /// 古い→新しい順で 7 要素固定。
    public var dailyBars: [DailyProgressBar]
    public var weekCompletedItems: Int
    /// サンプル 0 なら nil。
    public var shadowingAverageMatchRate: Double?
    public var shadowingSampleCount: Int
    /// pass+fail が 0 なら nil。
    public var compositionPassRate: Double?
    /// pass + fail 件数。
    public var compositionScoredCount: Int

    public init(
        streak: StreakSnapshot,
        dailyBars: [DailyProgressBar],
        weekCompletedItems: Int,
        shadowingAverageMatchRate: Double?,
        shadowingSampleCount: Int,
        compositionPassRate: Double?,
        compositionScoredCount: Int
    ) {
        self.streak = streak
        self.dailyBars = dailyBars
        self.weekCompletedItems = weekCompletedItems
        self.shadowingAverageMatchRate = shadowingAverageMatchRate
        self.shadowingSampleCount = shadowingSampleCount
        self.compositionPassRate = compositionPassRate
        self.compositionScoredCount = compositionScoredCount
    }
}

public enum ProgressSummarizer {
    /// ストリークと直近バー・モード平均を導出する純関数。
    /// - Parameters:
    ///   - activity: 全履歴の `LessonAttempt.createdAt`（ストリーク・total 用）
    ///   - windowSamples: 直近 30 学習日ぶんのサンプル（バー・平均用。呼び出し側が期間で絞る）
    ///   - goalItemsPerDay: 現在のデイリーゴール。0 以下なら `goalMet` は常に false
    ///   - now: 現在時刻（テストでは固定注入）
    ///   - calendar: 現在の端末タイムゾーンを持つ Calendar
    ///   - dayBoundaryHour: 学習日境界。既定は `StudyDay.defaultBoundaryHour`（04:00）
    ///   - grace: ストリーク救済ポリシー。既定 `.bridgeSingleRestDay`
    public static func summarize(
        activity: [Date],
        windowSamples: [ProgressSampleItem],
        goalItemsPerDay: Int,
        now: Date,
        calendar: Calendar,
        dayBoundaryHour: Int = StudyDay.defaultBoundaryHour,
        grace: StreakGracePolicy = .bridgeSingleRestDay
    ) -> ProgressSummary {
        let streak = StreakCalculator.snapshot(
            activity: activity,
            now: now,
            calendar: calendar,
            dayBoundaryHour: dayBoundaryHour,
            grace: grace
        )
        let dailyBars = makeDailyBars(
            windowSamples: windowSamples,
            goalItemsPerDay: goalItemsPerDay,
            now: now,
            calendar: calendar,
            dayBoundaryHour: dayBoundaryHour
        )
        let weekCompletedItems = dailyBars.reduce(0) { $0 + $1.completedItems }
        let shadowingRates = windowSamples.compactMap { sample -> Double? in
            guard sample.mode == .shadowing else { return nil }
            return sample.scriptMatchRate
        }
        let scoredComposition = windowSamples.filter { $0.mode == .composition && $0.passed != nil }
        let compositionPassCount = scoredComposition.filter { $0.passed == true }.count
        return ProgressSummary(
            streak: streak,
            dailyBars: dailyBars,
            weekCompletedItems: weekCompletedItems,
            shadowingAverageMatchRate: average(of: shadowingRates),
            shadowingSampleCount: shadowingRates.count,
            compositionPassRate: scoredComposition.isEmpty
                ? nil
                : Double(compositionPassCount) / Double(scoredComposition.count),
            compositionScoredCount: scoredComposition.count
        )
    }

    /// `now` の学習日を末尾とする暦日連続の直近 7 学習日。休み日も 0 件バーとして含む。
    private static func makeDailyBars(
        windowSamples: [ProgressSampleItem],
        goalItemsPerDay: Int,
        now: Date,
        calendar: Calendar,
        dayBoundaryHour: Int
    ) -> [DailyProgressBar] {
        let today = StudyDay.studyDay(of: now, calendar: calendar, dayBoundaryHour: dayBoundaryHour)
        var counts: [Date: Int] = [:]
        for sample in windowSamples {
            let day = StudyDay.studyDay(of: sample.createdAt, calendar: calendar, dayBoundaryHour: dayBoundaryHour)
            counts[day, default: 0] += 1
        }
        return (-6...0).compactMap { offset in
            guard let dayStart = calendar.date(byAdding: .day, value: offset, to: today) else {
                return nil
            }
            let completedItems = counts[dayStart] ?? 0
            let goalMet = goalItemsPerDay > 0 && completedItems >= goalItemsPerDay
            return DailyProgressBar(dayStart: dayStart, completedItems: completedItems, goalMet: goalMet)
        }
    }

    private static func average(of values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }
}
