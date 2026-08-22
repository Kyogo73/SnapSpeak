import DesignSystem
import SwiftUI
import UIKit

public struct ReviewSessionView<ItemContent: View>: View {
    @ObservedObject private var viewModel: ReviewSessionViewModel
    private let itemContent: (ReviewEntry, ReviewItemCallbacks) -> ItemContent
    private let onClose: () -> Void
    private let onContinueLearning: () -> Void
    private let didMeetGoal: Bool
    private let streakFrom: Int
    private let streakTo: Int
    @State private var confirmLeave = false

    public init(
        viewModel: ReviewSessionViewModel,
        @ViewBuilder itemContent: @escaping (ReviewEntry, ReviewItemCallbacks) -> ItemContent,
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
            case .newLessonIntro:
                newLessonIntroBody
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
                .accessibilityLabel(
                    LocalizedFormat.string("review.session.progress_a11y", index + 1, total)
                )
            if let entry = viewModel.current {
                itemContent(
                    entry,
                    ReviewItemCallbacks(complete: viewModel.advance, skip: viewModel.skip)
                )
            }
        }
        .padding()
        .onChange(of: index) { _, newIndex in
            announceItem(index: newIndex, total: total)
        }
    }

    private var newLessonIntroBody: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("review.session.new_lesson_divider")
                    .font(Typography.title)
                    .frame(maxWidth: .infinity, alignment: .leading)
                PrimaryButton("review.session.new_lesson_continue") {
                    viewModel.continueNewLesson()
                }
            }
            .padding()
        }
    }

    private func announceItem(index: Int, total: Int) {
        let announcement = LocalizedFormat.string("review.session.progress_a11y", index + 1, total)
        UIAccessibility.post(notification: .announcement, argument: announcement)
    }
}
