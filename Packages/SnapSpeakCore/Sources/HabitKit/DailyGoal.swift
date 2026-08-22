import Foundation

/// 1 日の学習目標（アイテム数）。UserSettings に保存される値の意味論を core に固定する。
public struct DailyGoal: Sendable, Equatable, Codable, Hashable {
    /// 1 学習日に完了するアイテム数。1 未満は 1 に正規化する。
    public var itemsPerDay: Int

    public init(itemsPerDay: Int) {
        self.itemsPerDay = max(itemsPerDay, 1)
    }

    public static let light = DailyGoal(itemsPerDay: 5)
    public static let standard = DailyGoal(itemsPerDay: 10)
    public static let serious = DailyGoal(itemsPerDay: 20)
    /// オンボーディングと Settings が提示する選択肢（自由入力は提供しない）。
    public static let presets: [DailyGoal] = [.light, .standard, .serious]
}

/// 今日のゴール進捗（導出値。保存しない）。
public struct GoalProgress: Sendable, Equatable {
    public var completedItems: Int
    public var goalItems: Int
    /// 0.0...1.0 にクランプ済み。
    public var fraction: Double
    public var isMet: Bool

    public init(completedItems: Int, goalItems: Int) {
        let completed = max(completedItems, 0)
        let goal = max(goalItems, 1)
        self.completedItems = completed
        self.goalItems = goal
        self.fraction = min(1.0, Double(completed) / Double(goal))
        self.isMet = completed >= goal
    }
}

public enum GoalEvaluator {
    /// 当日完了数と目標から進捗を導出する。completedToday < 0 は 0 に正規化。
    public static func progress(completedToday: Int, goal: DailyGoal) -> GoalProgress {
        GoalProgress(completedItems: completedToday, goalItems: goal.itemsPerDay)
    }
}
