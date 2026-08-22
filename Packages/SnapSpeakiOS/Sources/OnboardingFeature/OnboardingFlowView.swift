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
                            if let startLesson = await viewModel.skip() {
                                onFinished(startLesson)
                            }
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
                            if let startLesson = await viewModel.completeGoalStep() {
                                onFinished(startLesson)
                            }
                        }
                    },
                    onSkip: {
                        Task {
                            if let startLesson = await viewModel.skip() {
                                onFinished(startLesson)
                            }
                        }
                    }
                )
            }
        }
        .overlay(alignment: .top) {
            if viewModel.saveFailed {
                Text("onboarding.save_failed")
                    .font(.callout)
                    .padding(12)
                    .frame(maxWidth: .infinity)
                    .background(.red.opacity(0.12))
            }
        }
        .disabled(viewModel.isSaving)
        .onAppear { viewModel.appear() }
    }
}
