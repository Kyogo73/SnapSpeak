import ContentCore
import ContentKit
import DriveKit
import DriveModeFeature
import HabitKit
import Persistence
import SwiftUI

struct DriveSessionLaunch: Identifiable {
    let id = UUID()
    var plan: SessionPlan
    var settings: UserSettingsDTO
    var startImmediately: Bool
    var loadFailed: Bool
}

struct DriveSessionContainer: View {
    let launch: DriveSessionLaunch
    let courses: [StoredCourse]
    let dependencies: AppDependencies
    let today: TodayViewModel?
    let onClose: () -> Void
    let onOpenLesson: (LessonCoordinate) -> Void

    @StateObject private var viewModel: DriveSessionViewModel
    @State private var length: DriveScriptSettings.SessionLength

    init(
        launch: DriveSessionLaunch,
        courses: [StoredCourse],
        dependencies: AppDependencies,
        today: TodayViewModel?,
        onClose: @escaping () -> Void,
        onOpenLesson: @escaping (LessonCoordinate) -> Void
    ) {
        self.launch = launch
        self.courses = courses
        self.dependencies = dependencies
        self.today = today
        self.onClose = onClose
        self.onOpenLesson = onOpenLesson
        let recorder = DriveAttemptRecorder(
            persistence: dependencies.persistence,
            analytics: dependencies.analytics
        )
        let vm = DriveSessionViewModel(
            sequencer: dependencies.driveSequencer,
            recorder: recorder,
            analytics: dependencies.analytics
        )
        if launch.loadFailed {
            vm.markLoadFailed()
        } else {
            vm.prepare(
                plan: launch.plan,
                courses: courses,
                settings: DriveSettingsMapping.scriptSettings(from: launch.settings)
            )
        }
        vm.onOpenLesson = { courseId, lessonId, itemId, skill in
            let mode: LessonMode = skill == .composition ? .composition : .shadowing
            onOpenLesson(
                LessonCoordinate(courseId: courseId, lessonId: lessonId, itemId: itemId, mode: mode)
            )
        }
        _viewModel = StateObject(wrappedValue: vm)
        _length = State(
            initialValue: DriveSettingsMapping.sessionLength(minutes: launch.settings.driveSessionMinutes)
        )
    }

    var body: some View {
        DriveSessionView(
            viewModel: viewModel,
            length: $length,
            courses: courses,
            startImmediately: launch.startImmediately && !launch.loadFailed,
            speech: dependencies.speechSynthesis,
            files: dependencies.driveFilePlayer,
            onClose: {
                Task { await viewModel.stop() }
                onClose()
            },
            onRetry: {
                Task { await retry() }
            },
            onLengthChanged: { newLength in
                Task { await persistLength(newLength) }
            }
        )
        .task {
            await dependencies.audio.stop()
            dependencies.driveRemoteBridge.attach(sequencer: dependencies.driveSequencer)
            refreshNowPlaying()
        }
        .onChange(of: viewModel.phase) { _, _ in
            refreshNowPlaying()
        }
        .onChange(of: viewModel.completedCount) { _, _ in
            refreshNowPlaying()
        }
        .onChange(of: viewModel.currentCourseTitle) { _, _ in
            refreshNowPlaying()
        }
        .onDisappear {
            dependencies.driveRemoteBridge.detach()
            Task { await dependencies.driveSequencer.stop() }
        }
    }

    private func refreshNowPlaying() {
        let paused: Bool
        switch viewModel.phase {
        case let .running(_, _, isPaused):
            paused = isPaused
        case .starting:
            paused = false
        case .idle, .finished:
            paused = true
        }
        dependencies.driveRemoteBridge.updateNowPlaying(
            title: DriveAnnouncementText.nowPlayingTitle(),
            artist: DriveAnnouncementText.nowPlayingArtist(
                courseTitle: viewModel.currentCourseTitle,
                completed: viewModel.completedCount,
                planned: viewModel.plannedCount
            ),
            isPaused: paused
        )
    }

    private func persistLength(_ length: DriveScriptSettings.SessionLength) async {
        var dto = (try? await dependencies.persistence.loadOrCreateSettings()) ?? launch.settings
        dto = DriveSettingsMapping.applying(length: length, to: dto)
        _ = try? await dependencies.persistence.saveSettings(dto)
    }

    private func retry() async {
        guard let today else { return }
        let prepared = await today.prepareDrivePlan()
        if prepared.loadFailed {
            viewModel.markLoadFailed()
            return
        }
        let settings = (try? await dependencies.persistence.loadOrCreateSettings()) ?? launch.settings
        viewModel.prepare(
            plan: prepared.plan,
            courses: courses,
            settings: DriveSettingsMapping.scriptSettings(from: settings)
        )
    }
}
