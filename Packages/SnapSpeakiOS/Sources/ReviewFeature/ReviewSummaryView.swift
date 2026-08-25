import DesignSystem
import SwiftUI

public struct ReviewSummaryView: View {
    public var completedCount: Int
    public var skippedMissingCount: Int
    public var skippedByUserCount: Int
    public var completedItemsBefore: Int?
    public var completedItemsAfter: Int?
    public var goalItems: Int?
    public var didMeetGoal: Bool
    public var streakFrom: Int
    public var streakTo: Int
    public var onBackHome: () -> Void
    public var onContinue: () -> Void
    @State private var ringProgress: Double = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(
        completedCount: Int,
        skippedMissingCount: Int,
        skippedByUserCount: Int,
        completedItemsBefore: Int? = nil,
        completedItemsAfter: Int? = nil,
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
        self.completedItemsBefore = completedItemsBefore
        self.completedItemsAfter = completedItemsAfter
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
            if let completedItemsBefore, let completedItemsAfter, let goalItems {
                Text(
                    LocalizedFormat.string(
                        "review.summary.goal_progress",
                        completedItemsBefore,
                        completedItemsAfter,
                        goalItems
                    )
                )
                    .font(Typography.body)
            }
            if didMeetGoal {
                VStack(spacing: 12) {
                    ProgressRing(
                        progress: ringProgress,
                        accessibilityLabel: "home.goal.ring_label",
                        accessibilityValueText: goalRingValueText
                    )
                    .frame(maxWidth: .infinity)
                    .onAppear(perform: startGoalRingIfNeeded)
                    Label("review.summary.goal_met", systemImage: "checkmark.circle.fill")
                        .font(Typography.headline)
                        .foregroundStyle(Colors.success)
                }
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

    private var goalRingValueText: String {
        LocalizedFormat.string(
            "home.goal.progress",
            completedItemsAfter ?? completedCount,
            goalItems ?? max(completedItemsAfter ?? completedCount, 1)
        )
    }

    private func startGoalRingIfNeeded() {
        guard didMeetGoal else { return }
        if reduceMotion {
            ringProgress = 1
            return
        }
        ringProgress = 0
        withAnimation(.easeOut(duration: 0.6)) {
            ringProgress = 1
        }
    }
}
