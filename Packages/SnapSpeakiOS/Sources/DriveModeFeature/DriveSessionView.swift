import AudioEngine
import ContentKit
import DriveKit
import SwiftUI

public struct DriveSessionView: View {
    @ObservedObject var viewModel: DriveSessionViewModel
    @Binding var length: DriveScriptSettings.SessionLength
    public var courses: [StoredCourse]
    public var startImmediately: Bool
    public var onClose: () -> Void
    public var onRetry: () -> Void
    public var onLengthChanged: (DriveScriptSettings.SessionLength) -> Void
    public var speech: any SpeechSynthesizing
    public var files: any PhaseFilePlaying

    public init(
        viewModel: DriveSessionViewModel,
        length: Binding<DriveScriptSettings.SessionLength>,
        courses: [StoredCourse],
        startImmediately: Bool = false,
        speech: any SpeechSynthesizing,
        files: any PhaseFilePlaying,
        onClose: @escaping () -> Void,
        onRetry: @escaping () -> Void,
        onLengthChanged: @escaping (DriveScriptSettings.SessionLength) -> Void
    ) {
        self.viewModel = viewModel
        _length = length
        self.courses = courses
        self.startImmediately = startImmediately
        self.speech = speech
        self.files = files
        self.onClose = onClose
        self.onRetry = onRetry
        self.onLengthChanged = onLengthChanged
    }

    public var body: some View {
        Group {
            switch viewModel.phase {
            case .idle:
                DriveStartView(
                    dueCount: viewModel.dueCount,
                    newCount: viewModel.newCount,
                    isRepeatFill: viewModel.isRepeatFill,
                    loadFailed: viewModel.loadFailed,
                    canStart: viewModel.canStart,
                    length: $length,
                    onStart: {
                        viewModel.applyLength(length)
                        Task { await viewModel.start(courses: courses) }
                    },
                    onRetry: onRetry,
                    onClose: onClose
                )
            case .starting:
                DriveGlanceView(
                    phaseKind: .sessionIntro,
                    paused: false,
                    completed: viewModel.completedCount,
                    planned: viewModel.plannedCount,
                    onTogglePause: {},
                    onStop: { Task { await viewModel.stop() } }
                )
            case let .running(kind, _, paused):
                DriveGlanceView(
                    phaseKind: kind,
                    paused: paused,
                    completed: viewModel.completedCount,
                    planned: viewModel.plannedCount,
                    onTogglePause: {
                        Task {
                            if paused {
                                await viewModel.resume()
                            } else {
                                await viewModel.pause()
                            }
                        }
                    },
                    onStop: { Task { await viewModel.stop() } }
                )
            case .finished:
                DriveCompletedView(
                    completedCount: viewModel.completedCount,
                    onOpenNote: { viewModel.openNote() },
                    onClose: onClose
                )
            case let .reviewing(note):
                DriveNoteView(
                    note: note,
                    onReplay: { row in
                        Task { await viewModel.replay(row: row, speech: speech, files: files) }
                    },
                    onOpenLesson: { viewModel.openLesson($0) },
                    onClose: onClose
                )
                .onAppear { viewModel.noteOpened() }
            }
        }
        .onChange(of: length) { _, newValue in
            viewModel.applyLength(newValue)
            onLengthChanged(newValue)
        }
        .task {
            guard startImmediately, viewModel.canStart else { return }
            viewModel.applyLength(length)
            await viewModel.start(courses: courses)
        }
    }
}
