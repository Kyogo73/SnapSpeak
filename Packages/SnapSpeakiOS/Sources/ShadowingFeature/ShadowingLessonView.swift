import DesignSystem
import SwiftUI

public struct ShadowingLessonView: View {
    @StateObject private var viewModel: ShadowingLessonViewModel
    @Environment(\.dismiss) private var dismiss

    public init(viewModel: ShadowingLessonViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
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
                if case let .failed(message) = viewModel.phase {
                    Text("common.error")
                        .font(Typography.headline)
                    Text(message)
                        .font(Typography.caption)
                }
                if case .scored = viewModel.phase, let score = viewModel.score {
                    ResultView(
                        score: score,
                        onRetry: {
                            Task { await viewModel.load() }
                        },
                        onClose: { dismiss() }
                    )
                }
            }
            .padding()
        }
        .navigationTitle("shadowing.title")
        .task { await viewModel.load() }
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
}
