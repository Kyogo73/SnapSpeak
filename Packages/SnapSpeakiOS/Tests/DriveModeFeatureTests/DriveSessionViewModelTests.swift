import AudioEngine
import DriveKit
import DriveModeFeature
import Foundation
import HabitKit
import Persistence
import Testing

@Suite("DriveSessionViewModel")
@MainActor
struct DriveSessionViewModelTests {
    @Test("開始で drive_session_started、完了後は安全画面。ノートは明示タップ。Attempt は finish 確定前")
    func startAndFinishRecordAttemptThenOpenNote() async throws {
        let sequencer = FakeDriveSequencer()
        let persistence = try makeViewModelPersistence()
        let analytics = RecordingAnalytics()
        let recorder = DriveAttemptRecorder(persistence: persistence, analytics: analytics)
        let viewModel = DriveSessionViewModel(
            sequencer: sequencer,
            recorder: recorder,
            analytics: analytics
        )
        let course = try DriveTestSupport.shadowingCourse()
        let stored = DriveTestSupport.stored(course)
        let plan = SessionPlan(
            reviews: [DriveTestSupport.due(courseId: "course_a", itemId: "item_ok")],
            deferredDueCount: 0,
            newLesson: nil
        )
        viewModel.prepare(plan: plan, courses: [stored], settings: DriveScriptSettings.standard)
        #expect(viewModel.canStart)

        await viewModel.start(courses: [stored])
        #expect(analytics.events.contains {
            if case let .driveSessionStarted(due, new, code) = $0 {
                return due == 1 && new == 0 && code == "10"
            }
            return false
        })

        let ref = DriveItemRef(courseId: "course_a", itemId: "item_ok", skill: .shadowing, passIndex: 0)
        sequencer.emit(.phaseChanged(kind: .shadowTrack, itemRef: ref))
        sequencer.emit(.itemCompleted(ref, usedTTSFallback: true, elapsedMs: 2_500))
        sequencer.emit(.finished(endedByUser: false, completedCount: 1, usedTTSFallback: true))

        await waitUntil {
            if case .finished = viewModel.phase { return true }
            return false
        }
        #expect(viewModel.completedCount == 1)
        if case .reviewing = viewModel.phase {
            Issue.record("must stay on finished glance, not auto-open note")
        }

        let attempt = try await persistence.latestAttempt()
        #expect(attempt?.itemId == "item_ok")
        #expect(attempt?.payloadSchemaVersion == 2)

        viewModel.openNote()
        if case let .reviewing(note) = viewModel.phase {
            #expect(note.rows.count == 1)
            #expect(note.rows[0].itemId == "item_ok")
            #expect(note.usedTTSFallback == true)
            #expect(note.endReason == "finished")
            #expect(note.goalCompletedAfter >= note.goalCompletedBefore)
        } else {
            Issue.record("expected reviewing after explicit openNote")
        }

        await waitUntil { analytics.events.contains { event in
            if case let .driveSessionCompleted(count, _, reason, tts) = event {
                return count == 1 && reason == "finished" && tts
            }
            return false
        }}
    }

    @Test("pause / resume が running の paused を切り替える")
    func pauseAndResumeUpdatePhase() async throws {
        let sequencer = FakeDriveSequencer()
        let persistence = try makeViewModelPersistence()
        let viewModel = DriveSessionViewModel(
            sequencer: sequencer,
            recorder: DriveAttemptRecorder(persistence: persistence, analytics: RecordingAnalytics()),
            analytics: RecordingAnalytics()
        )
        let course = try DriveTestSupport.shadowingCourse()
        let stored = DriveTestSupport.stored(course)
        viewModel.prepare(
            plan: SessionPlan(
                reviews: [DriveTestSupport.due(courseId: "course_a", itemId: "item_ok")],
                deferredDueCount: 0,
                newLesson: nil
            ),
            courses: [stored],
            settings: DriveScriptSettings.standard
        )
        await viewModel.start(courses: [stored])
        let ref = DriveItemRef(courseId: "course_a", itemId: "item_ok", skill: .shadowing, passIndex: 0)
        sequencer.emit(.phaseChanged(kind: .shadowTrack, itemRef: ref))
        await waitUntil {
            if case .running = viewModel.phase { return true }
            return false
        }
        sequencer.emit(.paused(reason: .user))
        await waitUntil {
            if case let .running(_, _, paused) = viewModel.phase { return paused }
            return false
        }
        sequencer.emit(.resumed)
        await waitUntil {
            if case let .running(_, _, paused) = viewModel.phase { return !paused }
            return false
        }
    }

    @Test("途中停止でも finished の usedTTSFallback を分析に載せる")
    func stopStillReportsSessionTTS() async throws {
        let sequencer = FakeDriveSequencer()
        let persistence = try makeViewModelPersistence()
        let analytics = RecordingAnalytics()
        let viewModel = DriveSessionViewModel(
            sequencer: sequencer,
            recorder: DriveAttemptRecorder(persistence: persistence, analytics: analytics),
            analytics: analytics
        )
        let course = try DriveTestSupport.shadowingCourse()
        viewModel.prepare(
            plan: SessionPlan(
                reviews: [DriveTestSupport.due(courseId: "course_a", itemId: "item_ok")],
                deferredDueCount: 0,
                newLesson: nil
            ),
            courses: [DriveTestSupport.stored(course)],
            settings: DriveScriptSettings.standard
        )
        await viewModel.start(courses: [DriveTestSupport.stored(course)])
        sequencer.emit(.finished(endedByUser: true, completedCount: 0, usedTTSFallback: true))
        await waitUntil {
            if case .finished = viewModel.phase { return true }
            return false
        }
        #expect(analytics.events.contains {
            if case let .driveSessionCompleted(_, _, reason, tts) = $0 {
                return reason == "stopped" && tts
            }
            return false
        })
    }

    @Test("空 script では開始しない。購読後に start する")
    func emptyItemsDoNotStart() async throws {
        let sequencer = FakeDriveSequencer()
        let persistence = try makeViewModelPersistence()
        let viewModel = DriveSessionViewModel(
            sequencer: sequencer,
            recorder: DriveAttemptRecorder(persistence: persistence, analytics: RecordingAnalytics()),
            analytics: RecordingAnalytics()
        )
        viewModel.prepare(
            plan: SessionPlan(reviews: [], deferredDueCount: 0, newLesson: nil),
            courses: [],
            settings: DriveScriptSettings.standard
        )
        #expect(viewModel.canStart == false)
        await viewModel.start(courses: [])
        #expect(sequencer.didStart == false)
        #expect(viewModel.phase == .idle)
    }

    @Test("noteOpened は drive_note_opened を送る")
    func noteOpenedTracksEvent() async throws {
        let sequencer = FakeDriveSequencer()
        let persistence = try makeViewModelPersistence()
        let analytics = RecordingAnalytics()
        let viewModel = DriveSessionViewModel(
            sequencer: sequencer,
            recorder: DriveAttemptRecorder(persistence: persistence, analytics: analytics),
            analytics: analytics
        )
        let course = try DriveTestSupport.shadowingCourse()
        viewModel.prepare(
            plan: SessionPlan(
                reviews: [DriveTestSupport.due(courseId: "course_a", itemId: "item_ok")],
                deferredDueCount: 0,
                newLesson: nil
            ),
            courses: [DriveTestSupport.stored(course)],
            settings: DriveScriptSettings.standard
        )
        await viewModel.start(courses: [DriveTestSupport.stored(course)])
        sequencer.emit(.finished(endedByUser: true, completedCount: 0, usedTTSFallback: false))
        await waitUntil {
            if case .finished = viewModel.phase { return true }
            return false
        }
        viewModel.openNote()
        viewModel.noteOpened()
        #expect(analytics.events.contains {
            if case let .driveNoteOpened(count) = $0 { return count == 0 }
            return false
        })
        if case let .reviewing(note) = viewModel.phase {
            #expect(note.endReason == "stopped")
        } else {
            Issue.record("expected reviewing after openNote")
        }
    }
}

final class FakeDriveSequencer: DriveSequencing, @unchecked Sendable {
    private let stream: AsyncStream<DriveSequencerEvent>
    private let continuation: AsyncStream<DriveSequencerEvent>.Continuation
    private(set) var didStart = false
    private(set) var pauseCount = 0
    private(set) var resumeCount = 0

    init() {
        let pair = AsyncStream.makeStream(of: DriveSequencerEvent.self)
        stream = pair.stream
        continuation = pair.continuation
    }

    func events() async -> AsyncStream<DriveSequencerEvent> { stream }

    func start(
        script: DriveScript,
        announcementTexts: [DriveAnnouncement: String],
        outroText: @escaping @Sendable (Int) -> String,
        assets: (any DriveAssetResolving)?
    ) async {
        _ = script
        _ = announcementTexts
        _ = outroText
        _ = assets
        didStart = true
    }

    func pause() async { pauseCount += 1 }
    func resume() async { resumeCount += 1 }
    func skipForward() async {}
    func skipBackward() async {}
    func stop() async {}

    func emit(_ event: DriveSequencerEvent) {
        continuation.yield(event)
    }
}

private func makeViewModelPersistence() throws -> PersistenceActor {
    let container = try PersistenceActor.makeContainer(inMemory: true)
    return PersistenceActor(modelContainer: container)
}

@MainActor
private func waitUntil(timeoutMs: Int = 2_000, _ predicate: @escaping @MainActor () async -> Bool) async {
    let deadline = Date().addingTimeInterval(Double(timeoutMs) / 1_000)
    while Date() < deadline {
        if await predicate() { return }
        try? await Task.sleep(nanoseconds: 20_000_000)
    }
}
