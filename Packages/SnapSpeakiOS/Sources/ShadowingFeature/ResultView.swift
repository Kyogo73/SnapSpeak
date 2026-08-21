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
            PrimaryButton("result.retry", systemImage: "arrow.counterclockwise", action: onRetry)
            SecondaryButton("common.close", systemImage: "xmark", action: onClose)
        }
        .padding()
    }
}
