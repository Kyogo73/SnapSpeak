import Foundation
import HabitKit
import Testing

@Suite("GoalEvaluator")
struct GoalEvaluatorTests {
    @Test("goal 0 以下は 1 に正規化する")
    func goalZeroOrNegativeNormalizesToOne() {
        #expect(DailyGoal(itemsPerDay: 0).itemsPerDay == 1)
        #expect(DailyGoal(itemsPerDay: -5).itemsPerDay == 1)
        let progress = GoalEvaluator.progress(completedToday: 1, goal: DailyGoal(itemsPerDay: 0))
        #expect(progress.goalItems == 1)
        #expect(progress.isMet == true)
    }

    @Test("ちょうど達成")
    func exactlyMet() {
        let progress = GoalEvaluator.progress(completedToday: 10, goal: .standard)
        #expect(progress.completedItems == 10)
        #expect(progress.goalItems == 10)
        #expect(progress.fraction == 1.0)
        #expect(progress.isMet == true)
    }

    @Test("超過時 fraction=1.0 クランプ")
    func overflowClampsFraction() {
        let progress = GoalEvaluator.progress(completedToday: 25, goal: .standard)
        #expect(progress.completedItems == 25)
        #expect(progress.fraction == 1.0)
        #expect(progress.isMet == true)
    }

    @Test("負の completed は 0")
    func negativeCompletedNormalizesToZero() {
        let progress = GoalEvaluator.progress(completedToday: -3, goal: .standard)
        #expect(progress.completedItems == 0)
        #expect(progress.fraction == 0.0)
        #expect(progress.isMet == false)
    }

    @Test("isMet 境界（9/10 は false、10/10 は true）")
    func isMetBoundary() {
        let short = GoalEvaluator.progress(completedToday: 9, goal: .standard)
        #expect(short.isMet == false)
        #expect(short.fraction == 0.9)
        let met = GoalEvaluator.progress(completedToday: 10, goal: .standard)
        #expect(met.isMet == true)
    }

    @Test("プリセットは 5 / 10 / 20")
    func presets() {
        #expect(DailyGoal.light.itemsPerDay == 5)
        #expect(DailyGoal.standard.itemsPerDay == 10)
        #expect(DailyGoal.serious.itemsPerDay == 20)
        #expect(DailyGoal.presets == [.light, .standard, .serious])
    }
}
