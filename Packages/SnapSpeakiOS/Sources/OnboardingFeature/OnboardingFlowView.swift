import SwiftUI

public struct OnboardingFlowView: View {
    @ObservedObject private var viewModel: OnboardingViewModel
    private let onFinished: (_ startFirstLesson: Bool) -> Void

    public init(
        viewModel: OnboardingViewModel,
        onFinished: @escaping (_ startFirstLesson: Bool) -> Void
    ) {
        _viewModel = ObservedObject(wrappedValue: viewModel)
        self.onFinished = onFinished
    }

    public var body: some View {
        Group {
            switch viewModel.step {
            case .welcome:
                OnboardingWelcomeView(
                    onStart: { viewModel.advanceToGoal() },
                    onSkip: {
                        Task {
                            let startLesson = await viewModel.skip()
                            onFinished(startLesson)
                        }
                    }
                )
            case .goal:
                OnboardingGoalView(
                    selectedGoal: $viewModel.selectedGoal,
                    reminderEnabled: $viewModel.reminderEnabled,
                    reminderTime: $viewModel.reminderTime,
                    onStartLesson: {
                        Task {
                            let startLesson = await viewModel.completeGoalStep()
                            onFinished(startLesson)
                        }
                    },
                    onSkip: {
                        Task {
                            let startLesson = await viewModel.skip()
                            onFinished(startLesson)
                        }
                    }
                )
            }
        }
        .onAppear { viewModel.appear() }
    }
}
