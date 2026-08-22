import DesignSystem
import SwiftUI

public struct ReviewSummaryView: View {
    public var completedCount: Int
    public var skippedMissingCount: Int
    public var skippedByUserCount: Int
    public var completedItems: Int?
    public var goalItems: Int?
    public var didMeetGoal: Bool
    public var streakFrom: Int
    public var streakTo: Int
    public var onBackHome: () -> Void
    public var onContinue: () -> Void

    public init(
        completedCount: Int,
        skippedMissingCount: Int,
        skippedByUserCount: Int,
        completedItems: Int? = nil,
        goalItems: Int? = nil,
        didMeetGoal: Bool,
        streakFrom: Int,
        streakTo: Int,
        onBackHome: @escaping () -> Void,
        onContinue: @escaping () -> Void
    ) {
        self.completedCount = completedCount
        self.skippedMissingCount = skippedMissingCount
        self.skippedByUserCount = skippedByUserCount
        self.completedItems = completedItems
        self.goalItems = goalItems
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
            if skippedMissingCount > 0 {
                Text(LocalizedFormat.string("review.summary.skipped", skippedMissingCount))
                    .font(Typography.body)
                    .foregroundStyle(Colors.secondaryFill)
            }
            if skippedByUserCount > 0 {
                Text(LocalizedFormat.string("review.summary.skipped_user", skippedByUserCount))
                    .font(Typography.body)
                    .foregroundStyle(Colors.secondaryFill)
            }
            if let completedItems, let goalItems {
                Text(LocalizedFormat.string("home.goal.progress", completedItems, goalItems))
                    .font(Typography.body)
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
