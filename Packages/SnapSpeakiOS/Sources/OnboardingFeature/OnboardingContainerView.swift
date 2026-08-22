import Analytics
import NotificationsKit
import Persistence
import SwiftUI

/// `fullScreenCover` 内で ViewModel を安定所有する。
public struct OnboardingContainerView: View {
    @StateObject private var viewModel: OnboardingViewModel
    private let onFinished: (_ startFirstLesson: Bool) -> Void

    public init(
        persistence: PersistenceActor,
        scheduler: ReminderScheduler,
        analytics: any AnalyticsClient,
        onFinished: @escaping (_ startFirstLesson: Bool) -> Void
    ) {
        _viewModel = StateObject(
            wrappedValue: OnboardingViewModel(
                persistence: persistence,
                scheduler: scheduler,
                analytics: analytics
            )
        )
        self.onFinished = onFinished
    }

    public var body: some View {
        OnboardingFlowView(viewModel: viewModel, onFinished: onFinished)
    }
}
