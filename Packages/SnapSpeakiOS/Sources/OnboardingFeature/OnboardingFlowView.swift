import DesignSystem
import SwiftUI
import UIKit

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
        VStack(spacing: 0) {
            stepIndicator
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
        }
        .overlay(alignment: .top) {
            if viewModel.saveFailed {
                saveFailedBanner
            }
        }
        .disabled(viewModel.isSaving)
        .onAppear { viewModel.appear() }
        .onChange(of: viewModel.saveFailed) { _, failed in
            guard failed else { return }
            UIAccessibility.post(
                notification: .announcement,
                argument: String(localized: "onboarding.save_failed")
            )
        }
    }

    private var stepNumber: Int {
        viewModel.step == .welcome ? 1 : 2
    }

    private var stepIndicator: some View {
        HStack(spacing: 8) {
            Text(LocalizedFormat.string("onboarding.step", stepNumber, 2))
                .font(Typography.caption)
                .foregroundStyle(Colors.secondaryFill)
            Circle()
                .fill(stepNumber == 1 ? Colors.accent : Colors.secondaryFill)
                .frame(width: 8, height: 8)
                .accessibilityHidden(true)
            Circle()
                .fill(stepNumber == 2 ? Colors.accent : Colors.secondaryFill)
                .frame(width: 8, height: 8)
                .accessibilityHidden(true)
        }
        .padding(.top, 12)
    }

    private var saveFailedBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .accessibilityHidden(true)
            Text("onboarding.save_failed")
                .font(.callout)
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(.red.opacity(0.12))
    }
}
