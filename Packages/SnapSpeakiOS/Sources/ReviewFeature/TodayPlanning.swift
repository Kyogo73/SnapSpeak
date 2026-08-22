import Foundation
import HabitKit

/// 今日のプラン組立。失敗・遅延注入用の最小シーム（実装の差し替えはしない）。
public protocol TodayPlanning: Sendable {
    func makeToday(
        now: Date,
        timeZone: TimeZone,
        goal: DailyGoal,
        policy: SessionPlanPolicy
    ) async throws -> TodaySnapshot
}

extension TodayPlanService: TodayPlanning {}
