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
                case .failed:
                    Text("common.error")
                        .font(Typography.headline)
                    SecondaryButton("common.retry") {
                        Task { await viewModel.load() }
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
            }
            if let onCompleted {
                PrimaryButton("review.session.next", systemImage: "arrow.right", action: onCompleted)
            }
        }
    }
}
