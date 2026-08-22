@testable import AudioEngine
import DriveKit
import Foundation
import Testing

@Suite("DriveSequencer safety")
struct DriveSequencerSafetyTests {
    @Test("M3 cancellation 中は TTS fallback を始めない")
    func cancellationDoesNotStartTTSFallback() async throws {
        let speech = RecordingSpeech()
        let files = HangingFilePlayer()
        let session = FakeAudioSession()
        let sequencer = DriveSequencer(
            speech: speech,
            filePlayer: files,
            clock: InstantClock(),
            session: session,
            assets: FixedAssetResolver()
        )
        let collector = EventCollector(sequencer: sequencer)
        await collector.start()
        await sequencer.start(
            script: fileOnlyScript(),
            announcementTexts: [:],
            outroText: { _ in "" },
            assets: FixedAssetResolver()
        )
        await waitUntil { files.playCount == 1 }
        await sequencer.pause()
        try await Task.sleep(nanoseconds: 40_000_000)
        #expect(speech.speakCount == 0)
        #expect(collector.events.contains { $0 == .paused(reason: .user) })
        #expect(collector.events.contains { event in
            if case .itemCompleted = event { return true }
            return false
        } == false)
    }

    @Test("M5 route change は oldDeviceUnavailable のときだけ pause")
    func routeChangePausesOnlyWhenOldDeviceUnavailable() async throws {
        let speech = HangingSpeech()
        let sequencer = DriveSequencer(
            speech: speech,
            filePlayer: ImmediateFilePlayer(),
            clock: InstantClock(),
            session: FakeAudioSession(),
            assets: EmptyAssetResolver()
        )
        let collector = EventCollector(sequencer: sequencer)
        await collector.start()
        await sequencer.start(
            script: announcementScript(),
            announcementTexts: [.sessionIntro(dueCount: 0, newCount: 0, isRepeatFill: false, isEndless: false): "intro"],
            outroText: { _ in "" },
            assets: nil
        )
        await waitUntil { speech.speakCount == 1 }
        await sequencer.applyRecovery(.routeChange(oldDeviceUnavailable: false))
        try await Task.sleep(nanoseconds: 20_000_000)
        #expect(collector.events.contains { $0 == .paused(reason: .routeChange) } == false)
        await sequencer.applyRecovery(.routeChange(oldDeviceUnavailable: true))
        await waitUntil { collector.events.contains { $0 == .paused(reason: .routeChange) } }
        #expect(collector.events.contains { $0 == .paused(reason: .routeChange) })
    }

    @Test("M6 audio session 起動失敗で pause し進行しない")
    func audioSessionFailurePausesWithoutProgress() async throws {
        let speech = RecordingSpeech()
        let session = FakeAudioSession()
        session.activateShouldFail = true
        let sequencer = DriveSequencer(
            speech: speech,
            filePlayer: ImmediateFilePlayer(),
            clock: InstantClock(),
            session: session,
            assets: EmptyAssetResolver()
        )
        let collector = EventCollector(sequencer: sequencer)
        await collector.start()
        await sequencer.start(
            script: announcementScript(),
            announcementTexts: [.sessionIntro(dueCount: 0, newCount: 0, isRepeatFill: false, isEndless: false): "intro"],
            outroText: { _ in "" },
            assets: nil
        )
        await waitUntil { collector.events.contains { $0 == .paused(reason: .audioSessionFailure) } }
        #expect(speech.speakCount == 0)
        #expect(collector.events.contains { event in
            if case .phaseChanged = event { return true }
            return false
        } == false)
        #expect(collector.events.contains { event in
            if case .finished = event { return true }
            return false
        } == false)
    }

    @Test("S1 完了時に audio session を deactivate する")
    func finishDeactivatesAudioSession() async throws {
        let session = FakeAudioSession()
        let sequencer = DriveSequencer(
            speech: RecordingSpeech(),
            filePlayer: ImmediateFilePlayer(),
            clock: InstantClock(),
            session: session,
            assets: EmptyAssetResolver()
        )
        let collector = EventCollector(sequencer: sequencer)
        await collector.start()
        await sequencer.start(
            script: emptyFinishScript(),
            announcementTexts: [:],
            outroText: { _ in "" },
            assets: nil
        )
        await waitUntil {
            collector.events.contains { event in
                if case .finished = event { return true }
                return false
            }
        }
        #expect(session.deactivateCount == 1)
    }

    @Test("M7 media services reset で engine を作り直し pause を維持")
    func mediaServicesResetRebuildsAndPauses() async throws {
        let speech = HangingSpeech()
        let files = ImmediateFilePlayer()
        let sequencer = DriveSequencer(
            speech: speech,
            filePlayer: files,
            clock: InstantClock(),
            session: FakeAudioSession(),
            assets: EmptyAssetResolver()
        )
        let collector = EventCollector(sequencer: sequencer)
        await collector.start()
        await sequencer.start(
            script: announcementScript(),
            announcementTexts: [.sessionIntro(dueCount: 0, newCount: 0, isRepeatFill: false, isEndless: false): "intro"],
            outroText: { _ in "" },
            assets: nil
        )
        await waitUntil { speech.speakCount == 1 }
        await sequencer.applyRecovery(.mediaServicesReset)
        await waitUntil { collector.events.contains { $0 == .paused(reason: .mediaServicesReset) } }
        #expect(speech.resetCount == 1)
        #expect(files.resetCount == 1)
    }
}

@Suite("RequestBoundContinuation")
struct RequestBoundContinuationTests {
    @Test("M4 古い ID の callback は新しい continuation を完了しない")
    func staleIDDoesNotCompleteNewRequest() async throws {
        let box = ContinuationBox()
        let first = Task {
            try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
                box.begin(cont)
            }
        }
        await waitUntil { box.currentID != nil }
        let staleID = try #require(box.currentID)
        let second = Task {
            try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
                box.begin(cont)
            }
        }
        await waitUntil { box.currentID != staleID }
        await #expect(throws: SpeechSynthesisError.cancelled) {
            try await first.value
        }
        box.complete(id: staleID, .success(()))
        try await Task.sleep(nanoseconds: 20_000_000)
        #expect(second.isCancelled == false)
        let liveID = try #require(box.currentID)
        box.complete(id: liveID, .success(()))
        try await second.value
    }
}

private final class ContinuationBox: @unchecked Sendable {
    private let lock = NSLock()
    private var bound = RequestBoundContinuation()
    private var storedID: UUID?

    var currentID: UUID? {
        lock.lock()
        defer { lock.unlock() }
        return storedID
    }

    func begin(_ continuation: CheckedContinuation<Void, Error>) {
        lock.lock()
        storedID = bound.begin(continuation)
        lock.unlock()
    }

    func complete(id: UUID, _ result: Result<Void, Error>) {
        lock.lock()
        bound.complete(id: id, result)
        lock.unlock()
    }
}

private final class EventCollector: @unchecked Sendable {
    private let sequencer: DriveSequencer
    private let lock = NSLock()
    private var stored: [DriveSequencerEvent] = []
    private var task: Task<Void, Never>?

    var events: [DriveSequencerEvent] {
        lock.lock()
        defer { lock.unlock() }
        return stored
    }

    init(sequencer: DriveSequencer) {
        self.sequencer = sequencer
    }

    func start() async {
        let stream = await sequencer.events()
        task = Task {
            for await event in stream {
                self.append(event)
            }
        }
    }

    private func append(_ event: DriveSequencerEvent) {
        lock.lock()
        stored.append(event)
        lock.unlock()
    }
}

private final class RecordingSpeech: SpeechSynthesizing, @unchecked Sendable {
    private(set) var speakCount = 0
    private(set) var resetCount = 0

    func speak(text: String, languageTag: String) async throws {
        _ = text
        _ = languageTag
        speakCount += 1
    }

    func stopSpeaking() {}
    func resetEngine() { resetCount += 1 }
}

private final class HangingSpeech: SpeechSynthesizing, @unchecked Sendable {
    private(set) var speakCount = 0
    private(set) var resetCount = 0

    func speak(text: String, languageTag: String) async throws {
        _ = text
        _ = languageTag
        speakCount += 1
        try await Task.sleep(nanoseconds: 30_000_000_000)
    }

    func stopSpeaking() {}
    func resetEngine() { resetCount += 1 }
}

private final class HangingFilePlayer: PhaseFilePlaying, @unchecked Sendable {
    private var waiting: CheckedContinuation<Void, Error>?
    private(set) var playCount = 0
    private(set) var resetCount = 0

    func play(url: URL) async throws {
        _ = url
        playCount += 1
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            waiting = cont
        }
    }

    func stop() {
        waiting?.resume(throwing: CancellationError())
        waiting = nil
    }

    func resetEngine() { resetCount += 1 }
}

private final class ImmediateFilePlayer: PhaseFilePlaying, @unchecked Sendable {
    private(set) var resetCount = 0

    func play(url: URL) async throws { _ = url }
    func stop() {}
    func resetEngine() { resetCount += 1 }
}

private struct InstantClock: DriveClocking {
    func sleep(milliseconds: Int) async throws {
        _ = milliseconds
    }
}

private final class FakeAudioSession: AudioSessionConfiguring, @unchecked Sendable {
    var activateShouldFail = false
    private(set) var deactivateCount = 0

    func activatePreview() throws {
        if activateShouldFail {
            throw SpeechSynthesisError.voiceUnavailable
        }
    }

    func deactivate() throws {
        deactivateCount += 1
    }
}

private struct FixedAssetResolver: DriveAssetResolving {
    func fileURL(courseId: String, relativePath: String) -> URL? {
        _ = courseId
        _ = relativePath
        return URL(fileURLWithPath: "/tmp/drive-safety.m4a")
    }
}

private func fileOnlyScript() -> DriveScript {
    let ref = DriveItemRef(courseId: "c", itemId: "i", skill: .shadowing, passIndex: 0)
    let phase = DrivePhase(
        kind: .shadowTrack,
        audio: .file(
            courseId: "c",
            relativePath: "audio/i.m4a",
            fallbackText: "Hello",
            fallbackLanguageTag: "en"
        ),
        estimatedDurationMs: 1_000,
        item: ref
    )
    return DriveScript(phases: [phase], plannedTotalMs: 1_000, itemPassCount: 1, loops: false, omittedItemIds: [])
}

private func announcementScript() -> DriveScript {
    DriveScript(
        phases: [
            DrivePhase(
                kind: .sessionIntro,
                audio: .announcement(
                    .sessionIntro(dueCount: 0, newCount: 0, isRepeatFill: false, isEndless: false)
                ),
                estimatedDurationMs: 1_000,
                item: nil
            )
        ],
        plannedTotalMs: 1_000,
        itemPassCount: 0,
        loops: false,
        omittedItemIds: []
    )
}

private func emptyFinishScript() -> DriveScript {
    DriveScript(phases: [], plannedTotalMs: 0, itemPassCount: 0, loops: false, omittedItemIds: [])
}

private func waitUntil(timeoutMs: Int = 2_000, _ predicate: @escaping () async -> Bool) async {
    let deadline = Date().addingTimeInterval(Double(timeoutMs) / 1_000)
    while Date() < deadline {
        if await predicate() { return }
        try? await Task.sleep(nanoseconds: 10_000_000)
    }
}
