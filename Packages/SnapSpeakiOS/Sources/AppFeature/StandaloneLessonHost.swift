import CompositionFeature
import ShadowingFeature
import SwiftUI

/// 単発レッスン。完了 / スキップ後に画面を閉じる（セッションの「次へ」とは分離）。
struct StandaloneLessonHost: View {
    @Environment(\.dismiss) private var dismiss
    let coordinate: LessonCoordinate
    let dependencies: AppDependencies
    let today: TodayViewModel?

    var body: some View {
        let finish: () -> Void = {
            Task { await today?.refresh() }
            dismiss()
        }
        Group {
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
        .task {
            try? await dependencies.persistence.recordLastOpenedLesson(
                courseId: coordinate.courseId,
                lessonId: coordinate.lessonId,
                itemId: coordinate.itemId,
                mode: coordinate.mode.rawValue
            )
        }
    }
}
