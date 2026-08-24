import CompositionFeature
import ContentKit
import HabitKit
import ReviewFeature
import ShadowingFeature
import SwiftUI

struct ReviewSessionContainer: View {
    @StateObject private var session: ReviewSessionViewModel
    @State private var afterSnapshot: TodaySnapshot?
    let snapshot: TodaySnapshot
    @ObservedObject var dependencies: AppDependencies
    let courses: [StoredCourse]
    let onClose: () -> Void
    let onContinueLearning: () -> Void
    let onItemCompleted: () -> Void

    init(
        snapshot: TodaySnapshot,
        dependencies: AppDependencies,
        courses: [StoredCourse],
        onClose: @escaping () -> Void,
        onContinueLearning: @escaping () -> Void,
        onItemCompleted: @escaping () -> Void
    ) {
        _session = StateObject(
            wrappedValue: ReviewSessionViewModel(
                plan: snapshot.plan,
                courseStore: dependencies.courseStore,
                analytics: dependencies.analytics
            )
        )
        self.snapshot = snapshot
        self.dependencies = dependencies
        self.courses = courses
        self.onClose = onClose
        self.onContinueLearning = onContinueLearning
        self.onItemCompleted = onItemCompleted
    }

    var body: some View {
        let after = afterSnapshot
        let streakFrom = snapshot.streak.currentStreakDays
        let streakTo = after?.streak.currentStreakDays ?? streakFrom
        ReviewSessionView(
            viewModel: session,
            itemContent: { entry, actions in
                itemView(for: entry, actions: actions)
            },
            onClose: onClose,
            onContinueLearning: onContinueLearning,
            didMeetGoal: after?.goal.isMet ?? false,
            streakFrom: streakFrom,
            streakTo: streakTo,
            completedItemsBefore: after == nil ? nil : snapshot.goal.completedItems,
            completedItemsAfter: after?.goal.completedItems,
            goalItems: after?.goal.goalItems
        )
        .task(id: session.phase) {
            guard session.phase == .summary else { return }
            afterSnapshot = try? await loadAfterSnapshot()
        }
    }

    private func loadAfterSnapshot() async throws -> TodaySnapshot {
        let settings = try await dependencies.persistence.loadOrCreateSettings()
        return try await dependencies.todayPlanService.makeToday(
            now: Date(),
            timeZone: TimeZone.current,
            goal: DailyGoal(itemsPerDay: settings.dailyGoalItems),
            policy: .standard
        )
    }

    @ViewBuilder
    private func itemView(for entry: ReviewEntry, actions: ReviewItemCallbacks) -> some View {
        let locked = ContentAccess.access(
            resolver: dependencies.entitlement,
            courses: courses,
            courseId: entry.courseId,
            lessonId: entry.lessonId,
            skillIsComposition: entry.mode == .composition
        ) == .locked
        Group {
            if locked {
                PaywallView(
                    dependencies: dependencies,
                    reason: "review",
                    onClose: { actions.skip() }
                )
                .task {
                    dependencies.analytics.track(
                        .limitReached(
                            kind: ContentAccess.limitKind(
                                resolver: dependencies.entitlement,
                                skillIsComposition: entry.mode == .composition
                            )
                        )
                    )
                }
            } else {
                switch entry.mode {
                case .shadowing:
                    ShadowingLessonView(
                        viewModel: ShadowingLessonViewModel(
                            courseId: entry.courseId,
                            lessonId: entry.lessonId,
                            itemId: entry.itemId,
                            useCase: dependencies.shadowingUseCase,
                            courseStore: dependencies.courseStore,
                            captionsEnabled: dependencies.settings.captionsEnabled,
                            defaultRate: dependencies.settings.defaultRate
                        ),
                        onCompleted: {
                            onItemCompleted()
                            actions.complete()
                        },
                        onSkipped: {
                            onItemCompleted()
                            actions.skip()
                        }
                    )
                case .composition:
                    CompositionCardView(
                        viewModel: CompositionSessionViewModel(
                            courseId: entry.courseId,
                            lessonId: entry.lessonId,
                            itemId: entry.itemId,
                            useCase: dependencies.compositionUseCase,
                            courseStore: dependencies.courseStore
                        ),
                        onCompleted: {
                            onItemCompleted()
                            actions.complete()
                        }
                    )
                }
            }
        }
        .task {
            guard !locked else { return }
            try? await dependencies.persistence.recordLastOpenedLesson(
                courseId: entry.courseId,
                lessonId: entry.lessonId,
                itemId: entry.itemId,
                mode: entry.mode.rawValue
            )
        }
    }
}
