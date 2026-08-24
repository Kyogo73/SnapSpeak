import DesignSystem
import ScoringKit
import SwiftUI

public struct ResultView: View {
    public var score: ShadowingScore
    public var onRetry: () -> Void
    public var onClose: () -> Void

    public init(score: ShadowingScore, onRetry: @escaping () -> Void, onClose: @escaping () -> Void) {
        self.score = score
        self.onRetry = onRetry
        self.onClose = onClose
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("result.title")
                .font(Typography.title)
            ScoreBadge(value: score.scriptMatchRate, accessibilityLabel: "result.script_match_rate")
            Text("result.script_match_rate")
                .font(Typography.headline)
            Text("result.script_match_rate_help")
                .font(Typography.body)
                .foregroundStyle(Colors.secondaryFill)
            VStack(alignment: .leading, spacing: 8) {
                Text(LocalizedFormat.string("result.breakdown.omissions", Self.omittedWordCount(score.omissions)))
                Text(LocalizedFormat.string("result.breakdown.hesitations", score.hesitations))
                Text(LocalizedFormat.string("result.breakdown.wpm", score.wpm))
                if let delay = score.delayMsMedian {
                    Text(LocalizedFormat.string("result.breakdown.delay", delay))
                    if score.delayGranularity == .sentenceApproximate {
                        Text("result.breakdown.delay_approx")
                            .font(Typography.caption)
                            .foregroundStyle(Colors.secondaryFill)
                    }
                }
            }
            .font(Typography.body)
            PrimaryButton("result.retry", systemImage: "arrow.counterclockwise", action: onRetry)
            SecondaryButton("common.close", systemImage: "xmark", action: onClose)
        }
        .padding()
    }

    /// 抜けた語数 = 各区間の (endRefIndex - startRefIndex) の合計（半開区間）。
    /// internal（省略時も internal）。private にはしない。
    static func omittedWordCount(_ omissions: [AlignedSpan]) -> Int {
        omissions.reduce(0) { $0 + max(0, $1.endRefIndex - $1.startRefIndex) }
    }
}
