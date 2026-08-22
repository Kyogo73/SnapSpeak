import DesignSystem
import SwiftUI

public struct ReviewSessionView<ItemContent: View>: View {
    @ObservedObject private var viewModel: ReviewSessionViewModel
    private let itemContent: (ReviewEntry, @escaping () -> Void) -> ItemContent
    private let onClose: () -> Void
    private let onContinueLearning: () -> Void
    private let didMeetGoal: Bool
    private let streakFrom: Int
    private let streakTo: Int
    @State private var confirmLeave = false

    public init(
        viewModel: ReviewSessionViewModel,
        @ViewBuilder itemContent: @escaping (ReviewEntry, @escaping () -> Void) -> ItemContent,
        onClose: @escaping () -> Void,
        onContinueLearning: @escaping () -> Void = {},
        didMeetGoal: Bool = false,
        streakFrom: Int = 0,
        streakTo: Int = 0
    ) {
        _viewModel = ObservedObject(wrappedValue: viewModel)
        self.itemContent = itemContent
        self.onClose = onClose
        self.onContinueLearning = onContinueLearning
        self.didMeetGoal = didMeetGoal
        self.streakFrom = streakFrom
        self.streakTo = streakTo
    }

    public var body: some View {
        Group {
            switch viewModel.phase {
            case .loading:
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case let .running(index, total):
                runningBody(index: index, total: total)
            case .summary:
                ReviewSummaryView(
                    completedCount: viewModel.completedCount,
                    skippedCount: viewModel.skippedCount,
                    didMeetGoal: didMeetGoal,
                    streakFrom: streakFrom,
                    streakTo: streakTo,
                    onBackHome: onClose,
                    onContinue: onContinueLearning
                )
            }
        }
        .navigationTitle("review.session.title")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button {
                    if case .summary = viewModel.phase {
                        onClose()
                    } else {
                        confirmLeave = true
                    }
                } label: {
                    Image(systemName: "xmark")
                        .frame(minWidth: 44, minHeight: 44)
                }
                .accessibilityLabel("common.close")
            }
        }
        .confirmationDialog(
            "review.session.leave_title",
            isPresented: $confirmLeave,
            titleVisibility: .visible
        ) {
            Button("review.session.leave_confirm") { onClose() }
            Button("common.close", role: .cancel) {}
        } message: {
            Text("review.session.leave_message")
        }
        .task { await viewModel.load() }
    }

    @ViewBuilder
    private func runningBody(index: Int, total: Int) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(LocalizedFormat.string("review.session.progress", index + 1, total))
                .font(Typography.headline)
                .monospacedDigit()
                .frame(maxWidth: .infinity)
                .accessibilityLabel(LocalizedFormat.string("review.session.progress", index + 1, total))
            if let entry = viewModel.current {
                if shouldShowNewLessonDivider(index: index) {
                    Text("review.session.new_lesson_divider")
                        .font(Typography.caption)
                        .foregroundStyle(Colors.secondaryFill)
                        .frame(maxWidth: .infinity)
                }
                itemContent(entry, viewModel.advance)
            }
        }
        .padding()
    }

    private func shouldShowNewLessonDivider(index: Int) -> Bool {
        guard viewModel.entries.indices.contains(index) else { return false }
        guard viewModel.entries[index].origin == .newLesson else { return false }
        if index == 0 { return true }
        return viewModel.entries[index - 1].origin != .newLesson
    }
}
