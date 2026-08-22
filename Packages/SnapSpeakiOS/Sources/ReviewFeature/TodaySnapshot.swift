import Foundation
import HabitKit

public struct TodaySnapshot: Sendable, Equatable {
    public var streak: StreakSnapshot
    public var goal: GoalProgress
    public var plan: SessionPlan
    public var hasCourses: Bool

    public init(streak: StreakSnapshot, goal: GoalProgress, plan: SessionPlan, hasCourses: Bool) {
        self.streak = streak
        self.goal = goal
        self.plan = plan
        self.hasCourses = hasCourses
    }
}
