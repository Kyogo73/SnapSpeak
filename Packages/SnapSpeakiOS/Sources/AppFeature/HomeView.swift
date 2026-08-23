import ContentCore
import ContentKit
import DesignSystem
import HabitKit
import ReviewFeature
import ShadowingFeature
import SwiftUI

public struct HomeView: View {
    @Binding var path: [HomeDestination]
    public var courses: [StoredCourse]
    @ObservedObject var today: TodayViewModel
    public var onContinueLearning: () -> Void
    public var onOpenDrive: () -> Void
    public var onQuickStartDrive: () -> Void
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    public init(
        path: Binding<[HomeDestination]>,
        courses: [StoredCourse],
        today: TodayViewModel,
        onContinueLearning: @escaping () -> Void,
        onOpenDrive: @escaping () -> Void,
        onQuickStartDrive: @escaping () -> Void
    ) {
        _path = path
        self.courses = courses
        self.today = today
        self.onContinueLearning = onContinueLearning
        self.onOpenDrive = onOpenDrive
        self.onQuickStartDrive = onQuickStartDrive
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if today.asrDegraded {
                    DegradedBanner(titleKey: "degraded.no_asr")
                }
                if case let .recovery(totalDays, longest) = today.state {
                    recoveryCard(totalDays: totalDays, longest: longest)
                } else {
                    habitCard
                }
                progressLink
                todayCard
                if !courses.isEmpty {
                    driveCard
                }
                if let continueLesson = today.continueLesson {
                    continueCard(continueLesson)
                }
            }
            .padding()
        }
        .navigationTitle("home.title")
        .onAppear {
            Task { await today.refresh() }
        }
    }

    @ViewBuilder
    private var habitCard: some View {
        if let snapshot = today.snapshot {
            CardContainer {
                AdaptiveStack {
                    VStack(alignment: .leading, spacing: 4) {
                        StreakBadge(
                            days: snapshot.streak.currentStreakDays,
                            isAtRisk: snapshot.streak.isAtRisk,
                            accessibilityLabel: LocalizedStringKey(
                                LocalizedFormat.string("streak.badge_label", snapshot.streak.currentStreakDays)
                            ),
                            accessibilityHint: snapshot.streak.isAtRisk ? "streak.at_risk" : nil
                        )
                        Text(LocalizedFormat.string("streak.days", snapshot.streak.currentStreakDays))
                            .font(Typography.headline)
                        if snapshot.streak.isAtRisk {
                            Text("streak.at_risk")
                                .font(Typography.caption)
                                .foregroundStyle(Colors.warning)
                        }
                        if snapshot.streak.isOnLastGraceDay {
                            Text("streak.last_grace")
                                .font(Typography.caption)
                                .foregroundStyle(Colors.warning)
                        }
                        if snapshot.streak.currentStreakDays == 1 {
                            Text("streak.rule_note")
                                .font(Typography.caption)
                                .foregroundStyle(Colors.secondaryFill)
                        }
                    }
                    if !dynamicTypeSize.isAccessibilitySize {
                        Spacer()
                    }
                    ProgressRing(
                        progress: snapshot.goal.fraction,
                        accessibilityLabel: "home.goal.ring_label",
                        accessibilityValueText: LocalizedFormat.string(
                            "home.goal.progress",
                            snapshot.goal.completedItems,
                            snapshot.goal.goalItems
                        )
                    )
                }
                Text(
                    LocalizedFormat.string(
                        "home.goal.progress",
                        snapshot.goal.completedItems,
                        snapshot.goal.goalItems
                    )
                )
                .font(Typography.caption)
                .foregroundStyle(Colors.secondaryFill)
            }
        }
    }

    @ViewBuilder
    private var todayCard: some View {
        CardContainer {
            Text("home.title")
                .font(Typography.headline)
            if today.state == .failed {
                Text("home.today.load_failed")
                    .font(Typography.body)
                SecondaryButton("home.today.retry") {
                    Task { await today.refresh() }
                }
            } else if courses.isEmpty || today.state == .empty {
                Text("home.today.empty_course")
                    .font(Typography.body)
                SecondaryButton("catalog.title", action: onContinueLearning)
            } else if let snapshot = today.snapshot, snapshot.plan.isEmpty {
                Text("home.today.all_done_title")
                    .font(Typography.headline)
                Text("home.today.all_done_subtitle")
                    .font(Typography.body)
                    .foregroundStyle(Colors.secondaryFill)
                SecondaryButton("home.today.extra", action: onContinueLearning)
            } else if let snapshot = today.snapshot {
                Text(planSummary(snapshot.plan))
                    .font(Typography.body)
                    .foregroundStyle(Colors.secondaryFill)
                if snapshot.plan.deferredDueCount > 0 {
                    Text(LocalizedFormat.string("home.today.deferred", snapshot.plan.deferredDueCount))
                        .font(Typography.caption)
                        .foregroundStyle(Colors.secondaryFill)
                }
                PrimaryButton("home.today.start") {
                    Task {
                        if await today.regeneratePlanThenStart() {
                            path.append(.review)
                        }
                    }
                }
            }
        }
    }

    private func recoveryCard(totalDays: Int, longest: Int) -> some View {
        CardContainer {
            AdaptiveStack {
                VStack(alignment: .leading, spacing: 8) {
                    Text("streak.broken.title")
                        .font(Typography.headline)
                    Text(LocalizedFormat.string("streak.broken.subtitle", totalDays))
                        .font(Typography.body)
                    Text(LocalizedFormat.string("streak.longest", longest))
                        .font(Typography.caption)
                        .foregroundStyle(Colors.secondaryFill)
                    Text("streak.rule_note")
                        .font(Typography.caption)
                        .foregroundStyle(Colors.secondaryFill)
                }
            }
            PrimaryButton("streak.broken.restart") {
                Task {
                    await today.dismissRecovery()
                    if await today.regeneratePlanThenStart() {
                        path.append(.review)
                    }
                }
            }
            SecondaryButton("home.recovery.dismiss") {
                Task { await today.dismissRecovery() }
            }
        }
    }

    private var driveCard: some View {
        CardContainer {
            Button(action: onOpenDrive) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("home.drive.title")
                        .font(Typography.headline)
                    Text("home.drive.subtitle")
                        .font(Typography.body)
                        .foregroundStyle(Colors.secondaryFill)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            PrimaryButton("home.drive.quick_start", action: onQuickStartDrive)
        }
    }

    private var progressLink: some View {
        CardContainer {
            Button { path.append(.progress) } label: {
                Label("home.progress_link", systemImage: "chart.bar.fill")
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            }
        }
    }

    private func continueCard(_ lesson: LessonCoordinate) -> some View {
        CardContainer {
            Button {
                path.append(.lesson(lesson))
            } label: {
                Label("home.continue", systemImage: "play.circle.fill")
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            }
        }
    }

    private func planSummary(_ plan: SessionPlan) -> String {
        let hasReviews = !plan.reviews.isEmpty
        let hasNew = plan.newLesson != nil
        if hasReviews && hasNew {
            return LocalizedFormat.string("home.today.plan_review_and_new", plan.reviews.count)
        }
        if hasReviews {
            return LocalizedFormat.string("home.today.plan_review_only", plan.reviews.count)
        }
        if hasNew {
            return LocalizedFormat.string("home.today.plan_new_only")
        }
        return ""
    }
}
