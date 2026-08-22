import ContentCore
import ContentKit
import DesignSystem
import HabitKit
import ReviewFeature
import SwiftUI

public struct HomeView: View {
    @Binding var path: [HomeDestination]
    public var courses: [StoredCourse]
    @ObservedObject var today: TodayViewModel
    public var onContinueLearning: () -> Void

    public init(
        path: Binding<[HomeDestination]>,
        courses: [StoredCourse],
        today: TodayViewModel,
        onContinueLearning: @escaping () -> Void
    ) {
        _path = path
        self.courses = courses
        self.today = today
        self.onContinueLearning = onContinueLearning
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if case let .recovery(totalDays, longest) = today.state {
                    recoveryCard(totalDays: totalDays, longest: longest)
                } else {
                    habitCard
                }
                todayCard
                if let continueLesson {
                    continueCard(continueLesson)
                }
            }
            .padding()
        }
        .navigationTitle("tab.home")
    }

    @ViewBuilder
    private var habitCard: some View {
        if let snapshot = today.snapshot {
            CardContainer {
                HStack(alignment: .center, spacing: 16) {
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
                    }
                    Spacer()
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
            if courses.isEmpty || today.state == .empty {
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
                    path.append(.review)
                }
            }
        }
    }

    private func recoveryCard(totalDays: Int, longest: Int) -> some View {
        CardContainer {
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
            PrimaryButton("streak.broken.restart") {
                today.dismissRecovery()
                path.append(.review)
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
        var parts: [String] = []
        if !plan.reviews.isEmpty {
            parts.append(LocalizedFormat.string("home.today.review_count", plan.reviews.count))
        }
        if plan.newLesson != nil {
            parts.append(String(localized: String.LocalizationValue("home.today.new_lesson")))
        }
        return parts.joined(separator: " · ")
    }

    private var continueLesson: LessonCoordinate? {
        guard let snapshot = today.snapshot, snapshot.streak.totalStudyDays > 0 || snapshot.streak.studiedToday else {
            return nil
        }
        return firstLesson
    }

    private var firstLesson: LessonCoordinate? {
        guard let stored = courses.first,
              let lesson = stored.course.units.first?.lessons.first,
              let item = lesson.items.first
        else { return nil }
        return LessonCoordinate(
            courseId: stored.course.id,
            lessonId: lesson.id,
            itemId: item.id,
            mode: lesson.mode
        )
    }
}
