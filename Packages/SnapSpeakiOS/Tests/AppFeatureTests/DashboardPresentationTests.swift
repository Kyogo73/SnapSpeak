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
        #expect(DashboardPresentation.barYEnd(completedItems: 3) == 3)
        #expect(DashboardPresentation.barYEnd(completedItems: 1) == 1)
    }

    @Test("モード別 % の指標名は率があるときだけ出す（ss-j36 B）")
    func showsMetricCaptionOnlyWhenRateExists() {
        #expect(DashboardPresentation.showsMetricCaption(hasRate: true))
        #expect(DashboardPresentation.showsMetricCaption(hasRate: false) == false)
        #expect(DashboardPresentation.shadowingMetricKey == "dashboard.modes.shadowing_metric")
        #expect(DashboardPresentation.compositionMetricKey == "dashboard.modes.composition_metric")
    }
}
