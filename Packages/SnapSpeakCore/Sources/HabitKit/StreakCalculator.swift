import Foundation
import SRSKit

/// ストリーク救済ポリシー（ux-design §2.3）。
public enum StreakGracePolicy: Sendable, Equatable {
    /// 救済なし。1 学習日でも休むと途切れる。
    case none
    /// 休み 1 学習日までは橋渡しして継続（連続 2 日休むと途切れる）。休んだ日はカウントしない。
    case bridgeSingleRestDay

    var allowedConsecutiveRestDays: Int {
        switch self {
        case .none: return 0
        case .bridgeSingleRestDay: return 1
        }
    }
}

/// ストリークの導出スナップショット。正本は LessonAttempt 列（追記型）であり、本値は保存しない。
public struct StreakSnapshot: Sendable, Equatable {
    /// 現在継続中のストリーク（学習した日のみのカウント。橋渡し日は含めない）。
    public var currentStreakDays: Int
    /// 全履歴での最長ストリーク。
    public var longestStreakDays: Int
    /// 累計学習日数（ユニーク学習日）。
    public var totalStudyDays: Int
    /// 今日（現学習日）に 1 件以上の完了があるか。
    public var studiedToday: Bool
    /// currentStreakDays > 0 かつ今日未学習（通知文言の切替に使う）。
    public var isAtRisk: Bool
    /// 昨日を橋渡しして生きている状態（今日学習しないと明日途切れる）。
    public var isOnLastGraceDay: Bool

    public init(
        currentStreakDays: Int,
        longestStreakDays: Int,
        totalStudyDays: Int,
        studiedToday: Bool,
        isAtRisk: Bool,
        isOnLastGraceDay: Bool
    ) {
        self.currentStreakDays = currentStreakDays
        self.longestStreakDays = longestStreakDays
        self.totalStudyDays = totalStudyDays
        self.studiedToday = studiedToday
        self.isAtRisk = isAtRisk
        self.isOnLastGraceDay = isOnLastGraceDay
    }
}

public enum StreakCalculator {
    /// LessonAttempt の作成時刻列からストリークを導出する純関数。
    /// - Parameters:
    ///   - activity: 全 `LessonAttempt.createdAt`（順不同・重複可。同一学習日は 1 日に潰す）
    ///   - now: 現在時刻（テストでは固定注入）
    ///   - calendar: 現在の端末タイムゾーンを持つ Calendar。過去の時刻もこの暦で再解釈する
    ///     （タイムゾーン移動でストリークが ±1 日変動しうることを仕様として許容。ux-design §2.3）
    ///   - dayBoundaryHour: 学習日境界。既定は `StudyDay.defaultBoundaryHour`（04:00）
    ///   - grace: 救済ポリシー。既定 `.bridgeSingleRestDay`
    public static func snapshot(
        activity: [Date],
        now: Date,
        calendar: Calendar,
        dayBoundaryHour: Int = StudyDay.defaultBoundaryHour,
        grace: StreakGracePolicy = .bridgeSingleRestDay
    ) -> StreakSnapshot {
        let today = StudyDay.studyDay(of: now, calendar: calendar, dayBoundaryHour: dayBoundaryHour)
        let studiedDays = Set(
            activity.map { StudyDay.studyDay(of: $0, calendar: calendar, dayBoundaryHour: dayBoundaryHour) }
        )
        let studiedToday = studiedDays.contains(today)
        let totalStudyDays = studiedDays.count
        let allowedRest = grace.allowedConsecutiveRestDays
        let current = currentStreak(
            studiedDays: studiedDays,
            today: today,
            studiedToday: studiedToday,
            calendar: calendar,
            allowedRest: allowedRest
        )
        let longest = longestStreak(
            studiedDays: studiedDays,
            calendar: calendar,
            allowedRest: allowedRest
        )
        let isAtRisk = current > 0 && !studiedToday
        let isOnLastGraceDay: Bool
        if grace == .bridgeSingleRestDay, !studiedToday, current > 0,
           let yesterday = calendar.date(byAdding: .day, value: -1, to: today) {
            isOnLastGraceDay = !studiedDays.contains(yesterday)
        } else {
            isOnLastGraceDay = false
        }
        return StreakSnapshot(
            currentStreakDays: current,
            longestStreakDays: longest,
            totalStudyDays: totalStudyDays,
            studiedToday: studiedToday,
            isAtRisk: isAtRisk,
            isOnLastGraceDay: isOnLastGraceDay
        )
    }

    private static func currentStreak(
        studiedDays: Set<Date>,
        today: Date,
        studiedToday: Bool,
        calendar: Calendar,
        allowedRest: Int
    ) -> Int {
        guard let earliest = studiedDays.min() else { return 0 }
        let start: Date
        if studiedToday {
            start = today
        } else if let yesterday = calendar.date(byAdding: .day, value: -1, to: today) {
            start = yesterday
        } else {
            return 0
        }

        var counted = 0
        var restRun = 0
        var cursor: Date? = start
        while let day = cursor {
            if studiedDays.contains(day) {
                counted += 1
                restRun = 0
            } else {
                restRun += 1
                if restRun > allowedRest {
                    break
                }
            }
            if day <= earliest {
                break
            }
            cursor = calendar.date(byAdding: .day, value: -1, to: day)
        }
        return counted
    }

    private static func longestStreak(
        studiedDays: Set<Date>,
        calendar: Calendar,
        allowedRest: Int
    ) -> Int {
        guard let first = studiedDays.min(), let last = studiedDays.max() else { return 0 }
        var best = 0
        var current = 0
        var restRun = 0
        var cursor: Date? = first
        while let day = cursor {
            if studiedDays.contains(day) {
                current += 1
                restRun = 0
                best = max(best, current)
            } else {
                restRun += 1
                if restRun > allowedRest {
                    current = 0
                    restRun = 0
                }
            }
            if day >= last { break }
            cursor = calendar.date(byAdding: .day, value: 1, to: day)
        }
        return best
    }
}
