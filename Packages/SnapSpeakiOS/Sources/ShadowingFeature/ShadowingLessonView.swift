import DesignSystem
import SwiftUI

public struct ShadowingLessonView: View {
    @StateObject private var viewModel: ShadowingLessonViewModel
    @Environment(\.dismiss) private var dismiss
    public var onCompleted: (() -> Void)?
    public var onSkipped: (() -> Void)?

    public init(
        viewModel: ShadowingLessonViewModel,
        onCompleted: (() -> Void)? = nil,
        onSkipped: (() -> Void)? = nil
    ) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.onCompleted = onCompleted
        self.onSkipped = onSkipped
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("shadowing.title")
                    .font(Typography.title)
                if case .degradedNoASR = viewModel.phase {
                    DegradedBanner(titleKey: "degraded.no_asr")
                }
                if viewModel.decision?.isDegraded == true {
                    DegradedBanner(titleKey: "degraded.route", systemImage: "headphones")
                }
                if viewModel.captionsEnabled {
                    ForEach(Array(viewModel.captions.enumerated()), id: \.offset) { _, segment in
                        Text(segment.text)
                            .font(Typography.body)
                    }
                } else {
                    Text(viewModel.passageText)
                        .font(Typography.body)
                }
                Toggle("shadowing.captions", isOn: $viewModel.captionsEnabled)
                    .frame(minHeight: 44)
                ratePicker
                controls
                if case let .failed(kind) = viewModel.phase {
                    Text("common.error")
                        .font(Typography.headline)
                    Text(failureMessageKey(kind))
                        .font(Typography.body)
                    PrimaryButton("common.retry") {
                        Task { await retryFailed(kind) }
                    }
                }
                if case .microphoneDenied = viewModel.phase {
                    Text("shadowing.mic_denied")
                        .font(Typography.body)
                    PrimaryButton("shadowing.play_preview", systemImage: "play.fill") {
                        Task { await viewModel.replayPreview() }
                    }
                    if let onSkipped {
                        SecondaryButton("shadowing.skip", systemImage: "forward", action: onSkipped)
                    } else {
                        SecondaryButton("shadowing.skip") { dismiss() }
                    }
                }
                if isCompletedPhase {
                    if let score = viewModel.score {
                        ResultView(
                            score: score,
                            onRetry: {
                                Task { await viewModel.load() }
                            },
                            onClose: { dismiss() }
                        )
                    }
                    if let onCompleted {
                        PrimaryButton("review.session.next", systemImage: "arrow.right", action: onCompleted)
                    }
                }
            }
            .padding()
        }
        .navigationTitle("shadowing.title")
        .task { await viewModel.load() }
    }

    private var isCompletedPhase: Bool {
        switch viewModel.phase {
        case .scored, .completed:
            return true
        default:
            return false
        }
    }

    private var ratePicker: some View {
        Picker("shadowing.rate", selection: $viewModel.rate) {
            Text("0.5×").tag(Float(0.5))
            Text("0.75×").tag(Float(0.75))
            Text("1.0×").tag(Float(1.0))
            Text("1.25×").tag(Float(1.25))
            Text("1.5×").tag(Float(1.5))
        }
        .pickerStyle(.segmented)
        .frame(minHeight: 44)
    }

    @ViewBuilder
    private var controls: some View {
        switch viewModel.phase {
        case .ready, .degradedNoASR:
            PrimaryButton("shadowing.start", systemImage: "play.fill") {
                Task { await viewModel.start() }
            }
        case .playing:
            PrimaryButton("shadowing.stop", systemImage: "stop.fill") {
                Task { await viewModel.stopAndScore() }
            }
        case .scoring, .loading:
            ProgressView()
                .frame(minHeight: 44)
        default:
            EmptyView()
        }
    }

    private func failureMessageKey(_ kind: ShadowingLessonViewModel.FailureKind) -> LocalizedStringKey {
        switch kind {
        case .load:
            return "lesson.error.load"
        case .playback:
            return "lesson.error.playback"
        case .scoring:
            return "lesson.error.scoring"
        }
    }

    private func retryFailed(_ kind: ShadowingLessonViewModel.FailureKind) async {
        switch kind {
        case .load:
            await viewModel.load()
        case .playback:
            await viewModel.start()
        case .scoring:
            viewModel.retryAfterScoringFailure()
        }
    }
}
