import CompositionFeature
import ContentKit
import ShadowingFeature
import SwiftUI

/// 単発レッスン。完了 / スキップ後に画面を閉じる（セッションの「次へ」とは分離）。
struct StandaloneLessonHost: View {
    @Environment(\.dismiss) private var dismiss
    let coordinate: LessonCoordinate
    @ObservedObject var dependencies: AppDependencies
    let courses: [StoredCourse]
    let today: TodayViewModel?

    private var isLocked: Bool {
        ContentAccess.access(
            resolver: dependencies.entitlement,
            courses: courses,
            coordinate: coordinate
        ) == .locked
    }

    var body: some View {
        let finish: () -> Void = {
            Task {
                await dependencies.refreshEntitlementUsage()
                await today?.refresh()
            }
            dismiss()
        }
        Group {
            if isLocked {
                PaywallView(
                    dependencies: dependencies,
                    reason: "lesson",
                    onClose: { dismiss() }
                )
                .task {
                    dependencies.analytics.track(
                        .limitReached(
                            kind: ContentAccess.limitKind(
                                resolver: dependencies.entitlement,
                                skillIsComposition: coordinate.mode == .composition
                            )
                        )
                    )
                }
            } else {
                switch coordinate.mode {
                case .shadowing:
                    ShadowingLessonView(
                        viewModel: ShadowingLessonViewModel(
                            courseId: coordinate.courseId,
                            lessonId: coordinate.lessonId,
                            itemId: coordinate.itemId,
                            useCase: dependencies.shadowingUseCase,
                            courseStore: dependencies.courseStore,
                            captionsEnabled: dependencies.settings.captionsEnabled,
                            defaultRate: dependencies.settings.defaultRate
                        ),
                        onCompleted: finish,
                        onSkipped: finish
                    )
                case .composition:
                    CompositionCardView(
                        viewModel: CompositionSessionViewModel(
                            courseId: coordinate.courseId,
                            lessonId: coordinate.lessonId,
                            itemId: coordinate.itemId,
                            useCase: dependencies.compositionUseCase,
                            courseStore: dependencies.courseStore
                        ),
                        onCompleted: finish
                    )
                }
            }
        }
        .task {
            guard !isLocked else { return }
            try? await dependencies.persistence.recordLastOpenedLesson(
                courseId: coordinate.courseId,
                lessonId: coordinate.lessonId,
                itemId: coordinate.itemId,
                mode: coordinate.mode.rawValue
            )
        }
    }
}
