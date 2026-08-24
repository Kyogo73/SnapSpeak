import DesignSystem
import SwiftUI

public struct CompositionCardView: View {
    @StateObject private var viewModel: CompositionSessionViewModel
    public var onCompleted: (() -> Void)?

    public init(viewModel: CompositionSessionViewModel, onCompleted: (() -> Void)? = nil) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.onCompleted = onCompleted
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("composition.title")
                    .font(Typography.title)
                Text("composition.prompt")
                    .font(Typography.caption)
                    .foregroundStyle(Colors.secondaryFill)
                Text(viewModel.l1Text)
                    .font(Typography.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Colors.background, in: RoundedRectangle(cornerRadius: 12))
                switch viewModel.phase {
                case .prompt:
                    if viewModel.microphoneDenied {
                        Text("composition.mic_denied")
                            .font(Typography.caption)
                            .foregroundStyle(Colors.secondaryFill)
                    }
                    PrimaryButton("composition.speak", systemImage: "mic.fill") {
                        Task { await viewModel.startSpeaking() }
                    }
                    TypingInputView(text: $viewModel.typedText) {
                        Task { await viewModel.submitTyped() }
                    }
                    SecondaryButton("composition.hint", systemImage: "lightbulb") {
                        viewModel.revealHint()
                    }
                case .recording:
                    PrimaryButton("common.stop", systemImage: "stop.fill") {
                        Task { await viewModel.finishSpeaking() }
                    }
                case .result:
                    resultBlock
                case let .failed(kind):
                    Text("common.error")
                        .font(Typography.headline)
                    Text(failureMessageKey(kind))
                        .font(Typography.body)
                    PrimaryButton("common.retry") {
                        Task { await retryFailed(kind) }
                    }
                case .loading, .scoring:
                    ProgressView()
                        .frame(minHeight: 44)
                }
            }
            .padding()
        }
        .navigationTitle("composition.title")
        .task { await viewModel.load() }
    }

    @ViewBuilder
    private var resultBlock: some View {
        if let outcome = viewModel.outcome {
            switch outcome.grade {
            case .pass:
                Label("composition.pass", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(Colors.success)
                    .font(Typography.headline)
            case .fail:
                Label("composition.fail", systemImage: "xmark.circle.fill")
                    .foregroundStyle(Colors.danger)
                    .font(Typography.headline)
            case .unscored:
                Label("composition.unscored", systemImage: "minus.circle.fill")
                    .foregroundStyle(Colors.warning)
                    .font(Typography.headline)
                Text("composition.type_instead")
                    .font(Typography.caption)
                    .foregroundStyle(Colors.secondaryFill)
                TypingInputView(text: $viewModel.typedText) {
                    Task { await viewModel.submitTyped() }
                }
            }
            if let onCompleted {
                PrimaryButton("review.session.next", systemImage: "arrow.right", action: onCompleted)
            }
        }
    }

    private func failureMessageKey(_ kind: CompositionSessionViewModel.FailureKind) -> LocalizedStringKey {
        switch kind {
        case .load:
            return "lesson.error.load"
        case .playback:
            return "lesson.error.playback"
        case .scoring:
            return "lesson.error.scoring"
        }
    }

    private func retryFailed(_ kind: CompositionSessionViewModel.FailureKind) async {
        switch kind {
        case .load:
            await viewModel.load()
        case .playback:
            await viewModel.startSpeaking()
        case .scoring:
            viewModel.retryAfterScoringFailure()
        }
    }
}
