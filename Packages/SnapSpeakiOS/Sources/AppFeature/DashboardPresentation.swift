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
}
