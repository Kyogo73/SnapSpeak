import Foundation

/// ダッシュボード表示の純関数（hostless テスト対象）。SwiftUI / Charts には依存しない。
public enum DashboardPresentation {
    /// 0 件日を欠測に見せないためのチャート内最小高さ（`BarMark` の `yEnd`）。
    public static let zeroBarPlaceholderYEnd = 0.15

    public static func usesZeroPlaceholder(completedItems: Int) -> Bool {
        completedItems == 0
    }

    public static func barYEnd(completedItems: Int) -> Double {
        usesZeroPlaceholder(completedItems: completedItems)
            ? zeroBarPlaceholderYEnd
            : Double(completedItems)
    }

    /// 全日 0 件でも Y 軸最大がプレースホルダ値に縮まないようにする。
    public static func chartYScaleUpperBound(completedItems: [Int]) -> Double {
        Double(max(1, completedItems.max() ?? 0))
    }

    public static let shadowingMetricKey = "dashboard.modes.shadowing_metric"
    public static let compositionMetricKey = "dashboard.modes.composition_metric"

    /// `no_data` 時は指標名だけ出すと空状態が曖昧になるため出さない。
    public static func showsMetricCaption(hasRate: Bool) -> Bool {
        hasRate
    }

    public static let atRiskCaptionKey = "streak.at_risk"

    public static func showsAtRiskCaption(isAtRisk: Bool) -> Bool {
        isAtRisk
    }

    public static let noteKeys = [
        "dashboard.metric_note",
        "dashboard.local_note",
        "dashboard.window_note",
    ]

    public static let weekSummaryAccessibilityKey = "dashboard.week.summary_a11y"

    public static func showsGoalMetMark(goalMet: Bool) -> Bool {
        goalMet
    }
}
