import AppFeature
import Testing

@Suite("DashboardPresentation")
struct DashboardPresentationTests {
    @Test("0 件日のバーは最小高さプレースホルダを使う（ss-j36 A）")
    func zeroDayBarUsesPlaceholderHeight() {
        #expect(DashboardPresentation.usesZeroPlaceholder(completedItems: 0))
        #expect(DashboardPresentation.barYEnd(completedItems: 0) == DashboardPresentation.zeroBarPlaceholderYEnd)
        #expect(DashboardPresentation.zeroBarPlaceholderYEnd > 0)
    }

    @Test("1 件以上の日は実数を y に使いプレースホルダにしない")
    func nonzeroDayBarUsesActualCount() {
        #expect(DashboardPresentation.usesZeroPlaceholder(completedItems: 3) == false)
        #expect(DashboardPresentation.barYEnd(completedItems: 3) == 3.0)
        #expect(DashboardPresentation.barYEnd(completedItems: 1) == 1.0)
    }

    @Test("モード別 % の指標名は率があるときだけ出す（ss-j36 B）")
    func showsMetricCaptionOnlyWhenRateExists() {
        #expect(DashboardPresentation.showsMetricCaption(hasRate: true))
        #expect(DashboardPresentation.showsMetricCaption(hasRate: false) == false)
        #expect(DashboardPresentation.shadowingMetricKey == "dashboard.modes.shadowing_metric")
        #expect(DashboardPresentation.compositionMetricKey == "dashboard.modes.composition_metric")
    }

    @Test("ストリーク at-risk はテキストでも出す（ss-j36 C）")
    func showsAtRiskCaptionWhenAtRisk() {
        #expect(DashboardPresentation.showsAtRiskCaption(isAtRisk: true))
        #expect(DashboardPresentation.showsAtRiskCaption(isAtRisk: false) == false)
        #expect(DashboardPresentation.atRiskCaptionKey == "streak.at_risk")
    }

    @Test("注記は 30 学習日窓を含む 3 行（ss-j36 D）")
    func noteKeysIncludeThirtyDayWindow() {
        #expect(DashboardPresentation.noteKeys == [
            "dashboard.metric_note",
            "dashboard.local_note",
            "dashboard.window_note",
        ])
        #expect(DashboardPresentation.noteKeys.count == 3)
    }

    @Test("チャート全体の a11y は合計を含む要約キー")
    func weekChartUsesSummaryAccessibilityKey() {
        #expect(DashboardPresentation.weekSummaryAccessibilityKey == "dashboard.week.summary_a11y")
    }

    @Test("達成日は色以外のチェック記号を出す")
    func showsGoalMetMarkWhenGoalMet() {
        #expect(DashboardPresentation.showsGoalMetMark(goalMet: true))
        #expect(DashboardPresentation.showsGoalMetMark(goalMet: false) == false)
    }
}
