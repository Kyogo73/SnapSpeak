import DesignSystem
import SwiftUI

public struct ReviewSummaryView: View {
    public var completedCount: Int
    public var skippedCount: Int
    public var didMeetGoal: Bool
    public var streakFrom: Int
    public var streakTo: Int
    public var onBackHome: () -> Void
    public var onContinue: () -> Void

    public init(
        completedCount: Int,
        skippedCount: Int,
        didMeetGoal: Bool,
        streakFrom: Int,
        streakTo: Int,
        onBackHome: @escaping () -> Void,
        onContinue: @escaping () -> Void
    ) {
        self.completedCount = completedCount
        self.skippedCount = skippedCount
        self.didMeetGoal = didMeetGoal
        self.streakFrom = streakFrom
        self.streakTo = streakTo
        self.onBackHome = onBackHome
        self.onContinue = onContinue
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
            Text("review.summary.title")
                .font(Typography.title)
            Text(LocalizedFormat.string("review.summary.completed", completedCount))
                .font(Typography.headline)
            if skippedCount > 0 {
                Text(LocalizedFormat.string("review.summary.skipped", skippedCount))
                    .font(Typography.body)
                    .foregroundStyle(Colors.secondaryFill)
            }
            if didMeetGoal {
                Label("review.summary.goal_met", systemImage: "checkmark.circle.fill")
                    .font(Typography.headline)
                    .foregroundStyle(Colors.success)
            }
            if streakTo > streakFrom {
                Text(LocalizedFormat.string("review.summary.streak_extended", streakFrom, streakTo))
                    .font(Typography.body)
            }
            PrimaryButton("review.summary.back_home", systemImage: "house", action: onBackHome)
            SecondaryButton("home.today.extra", action: onContinue)
            }
            .padding()
        }
    }
}
