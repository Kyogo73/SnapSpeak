import Foundation
import SRSKit

public struct ReminderSettings: Sendable, Equatable, Hashable {
    public var isEnabled: Bool
    /// 0...23 / 0...59。範囲外は plan() が空を返す（無効設定は通知しない）。
    public var hour: Int
    public var minute: Int

    public init(isEnabled: Bool, hour: Int, minute: Int) {
        self.isEnabled = isEnabled
        self.hour = hour
        self.minute = minute
    }
}

public enum ReminderKind: String, Sendable, Codable, Equatable {
    case daily
    case streakRisk = "streak_risk"
}

/// 予約 1 件分の予定（OS 非依存の DTO。NotificationsKit が UNNotificationRequest に写像する）。
public struct PlannedReminder: Sendable, Equatable, Identifiable {
    /// "reminder-<yyyy-MM-dd>"（fireAt のカレンダー日。冪等な入れ替えキー）。
    public var id: String
    public var fireAt: Date
    public var kind: ReminderKind
    /// 文言整形用（streakRisk のとき現在ストリーク日数）。
    public var streakDays: Int

    public init(id: String, fireAt: Date, kind: ReminderKind, streakDays: Int) {
        self.id = id
        self.fireAt = fireAt
        self.kind = kind
        self.streakDays = streakDays
    }
}

public enum ReminderPlanner {
    /// 今後 horizonDays 日分の通知予定を返す純関数（ux-design §6）。
    public static func plan(
        settings: ReminderSettings,
        streak: StreakSnapshot,
        now: Date,
        calendar: Calendar,
        dayBoundaryHour: Int = StudyDay.defaultBoundaryHour,
        horizonDays: Int = 3
    ) -> [PlannedReminder] {
        guard settings.isEnabled else { return [] }
        guard (0...23).contains(settings.hour), (0...59).contains(settings.minute) else {
            return []
        }
        guard horizonDays > 0 else { return [] }

        let todayStudyDay = StudyDay.studyDay(of: now, calendar: calendar, dayBoundaryHour: dayBoundaryHour)
        let startOfToday = calendar.startOfDay(for: now)
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"

        var results: [PlannedReminder] = []
        for offset in 0..<horizonDays {
            guard let day = calendar.date(byAdding: .day, value: offset, to: startOfToday) else {
                continue
            }
            var components = calendar.dateComponents([.year, .month, .day], from: day)
            components.hour = settings.hour
            components.minute = settings.minute
            components.second = 0
            guard let fireAt = calendar.date(from: components) else { continue }
            // 存在しない壁時計時刻（DST 春の飛び）は別時刻へ丸められるので捨てる。
            if calendar.component(.hour, from: fireAt) != settings.hour
                || calendar.component(.minute, from: fireAt) != settings.minute {
                continue
            }
            if fireAt <= now { continue }

            let fireStudyDay = StudyDay.studyDay(
                of: fireAt,
                calendar: calendar,
                dayBoundaryHour: dayBoundaryHour
            )
            if streak.studiedToday && fireStudyDay == todayStudyDay {
                continue
            }

            let kind: ReminderKind
            if results.isEmpty, fireStudyDay == todayStudyDay, streak.isAtRisk {
                kind = .streakRisk
            } else {
                kind = .daily
            }
            let id = "reminder-\(formatter.string(from: fireAt))"
            results.append(
                PlannedReminder(
                    id: id,
                    fireAt: fireAt,
                    kind: kind,
                    streakDays: streak.currentStreakDays
                )
            )
        }
        return results
    }
}
