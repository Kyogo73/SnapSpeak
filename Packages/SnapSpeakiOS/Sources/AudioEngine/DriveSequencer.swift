import AVFoundation
import DriveKit
import Foundation

/// `DriveScript` を 1 フェーズずつ実行する。進行判断は `DriveCursor` に委譲する。
public actor DriveSequencer: DriveSequencing {
    private let speech: any SpeechSynthesizing
    private let filePlayer: any PhaseFilePlaying
    private let clock: any DriveClocking
    private let session: any AudioSessionConfiguring
    private var assets: any DriveAssetResolving
    private let recovery = RecoveryObserver()

    private var cursor: DriveCursor?
    private var script: DriveScript?
    private var announcementTexts: [DriveAnnouncement: String] = [:]
    private var outroText: (@Sendable (Int) -> String)?
    private var generation: UInt64 = 0
    private var playTask: Task<Void, Never>?
    private var recoveryTask: Task<Void, Never>?
    private var itemSegmentStartedAt: Date?
    private var itemAccumulatedMs = 0
    private var itemUsedTTS = false
    private var sessionUsedTTS = false
    private var continuations: [UUID: AsyncStream<DriveSequencerEvent>.Continuation] = [:]

    public init(
        speech: any SpeechSynthesizing,
        filePlayer: any PhaseFilePlaying,
        clock: any DriveClocking = ContinuousClockSleeper(),
        session: any AudioSessionConfiguring = AudioSessionConfigurator(),
        assets: any DriveAssetResolving = EmptyAssetResolver()
    ) {
        self.speech = speech
        self.filePlayer = filePlayer
        self.clock = clock
        self.session = session
        self.assets = assets
    }

    public func events() async -> AsyncStream<DriveSequencerEvent> {
        AsyncStream { continuation in
            let id = UUID()
            continuations[id] = continuation
            continuation.onTermination = { _ in
                Task { await self.removeContinuation(id) }
            }
        }
    }

    public func start(
        script: DriveScript,
        announcementTexts: [DriveAnnouncement: String],
        outroText: @escaping @Sendable (Int) -> String,
        assets: (any DriveAssetResolving)? = nil
    ) async {
        generation += 1
        await haltPlayback()
        if let assets {
            self.assets = assets
        }
        self.script = script
        self.announcementTexts = announcementTexts
        self.outroText = outroText
        sessionUsedTTS = false
        resetItemTiming()
        var next = DriveCursor(script: script)
        let outputs = next.start()
        cursor = next
        startRecoveryMonitoring()
        do {
            try session.activatePreview()
        } catch {
            _ = next.apply(.pause)
            cursor = next
            emit(.paused(reason: .audioSessionFailure))
            return
        }
        await handle(outputs, generation: generation)
    }

    public func pause() async {
        await pause(reason: .user)
    }

    public func resume() async {
        guard var cursor, cursor.isPaused else { return }
        do {
            try session.activatePreview()
        } catch {
            emit(.paused(reason: .audioSessionFailure))
            return
        }
        generation += 1
        let gen = generation
        resetItemTiming()
        let outputs = cursor.apply(.resume)
        self.cursor = cursor
        emit(.resumed)
        await handle(outputs, generation: gen)
    }

    public func skipForward() async {
        generation += 1
        let gen = generation
        await haltPlayback(resetCursor: false)
        resetItemTiming()
        guard var cursor else { return }
        let outputs = cursor.apply(.skipToNextItem)
        self.cursor = cursor
        await handle(outputs, generation: gen)
    }

    public func skipBackward() async {
        generation += 1
        let gen = generation
        await haltPlayback(resetCursor: false)
        resetItemTiming()
        guard var cursor else { return }
        let outputs = cursor.apply(.previousPressed)
        self.cursor = cursor
        await handle(outputs, generation: gen)
    }

    public func stop() async {
        generation += 1
        await haltPlayback(resetCursor: false)
        guard var cursor else { return }
        let outputs = cursor.apply(.stop)
        self.cursor = cursor
        await handle(outputs, generation: generation)
        await recovery.stop()
        recoveryTask?.cancel()
        recoveryTask = nil
    }

    /// テスト用。割り込み / 経路変更を注入する。
    public func applyRecovery(_ event: RecoveryEvent) async {
        await handleRecovery(event)
    }

    private func pause(reason: DrivePauseReason) async {
        guard var cursor, !cursor.isPaused else { return }
        generation += 1
        await haltPlayback(resetCursor: false)
        _ = cursor.apply(.pause)
        self.cursor = cursor
        emit(.paused(reason: reason))
    }

    private func handle(_ outputs: [DriveCursor.Output], generation gen: UInt64) async {
        for output in outputs {
            guard gen == generation else { return }
            switch output {
            case let .play(index):
                playTask = Task { await self.playPhase(index, generation: gen) }
                return
            case let .itemCompleted(ref):
                emit(.itemCompleted(ref, usedTTSFallback: itemUsedTTS, elapsedMs: elapsedMs()))
                resetItemTiming()
            case let .finished(endedByUser):
                emit(
                    .finished(
                        endedByUser: endedByUser,
                        completedCount: cursor?.completedPassCount ?? 0,
                        usedTTSFallback: sessionUsedTTS
                    )
                )
                await recovery.stop()
                try? session.deactivate()
            }
        }
    }

    private func playPhase(_ index: Int, generation gen: UInt64) async {
        guard gen == generation, let script, script.phases.indices.contains(index) else { return }
        let phase = script.phases[index]
        if let item = phase.item, isFirstPhase(of: item, at: index, in: script) {
            resetItemTiming()
            itemSegmentStartedAt = Date()
        }
        emit(.phaseChanged(kind: phase.kind, itemRef: phase.item))
        do {
            try await render(phase, generation: gen)
        } catch SpeechSynthesisError.voiceUnavailable {
            guard gen == generation, var cursor else { return }
            if let item = phase.item {
                emit(.itemSkipped(item))
            }
            resetItemTiming()
            let outputs = cursor.apply(.skipToNextItem)
            self.cursor = cursor
            await handle(outputs, generation: gen)
            return
        } catch is CancellationError {
            return
        } catch SpeechSynthesisError.cancelled {
            return
        } catch {
            return
        }
        guard gen == generation, var cursor else { return }
        let outputs = cursor.apply(.phaseFinished)
        self.cursor = cursor
        await handle(outputs, generation: gen)
    }

    private func render(_ phase: DrivePhase, generation gen: UInt64) async throws {
        switch phase.audio {
        case let .announcement(announcement):
            let text = announcementText(announcement)
            try await speech.speak(text: text, languageTag: "ja")
        case let .contentTTS(text, tag):
            markTTSIfContent(phase)
            try await speech.speak(text: text, languageTag: tag)
        case let .file(courseId, relativePath, fallbackText, fallbackTag):
            try await playFileOrFallback(
                courseId: courseId,
                relativePath: relativePath,
                fallbackText: fallbackText,
                fallbackTag: fallbackTag,
                generation: gen
            )
        case .silence:
            try await clock.sleep(milliseconds: phase.estimatedDurationMs)
        }
    }

    private func playFileOrFallback(
        courseId: String,
        relativePath: String,
        fallbackText: String,
        fallbackTag: String,
        generation gen: UInt64
    ) async throws {
        if let url = assets.fileURL(courseId: courseId, relativePath: relativePath) {
            do {
                try await filePlayer.play(url: url)
                return
            } catch is CancellationError {
                throw CancellationError()
            } catch SpeechSynthesisError.cancelled {
                throw SpeechSynthesisError.cancelled
            } catch {
                try ensureCanFallback(generation: gen)
                itemUsedTTS = true
                sessionUsedTTS = true
            }
        } else {
            try ensureCanFallback(generation: gen)
            itemUsedTTS = true
            sessionUsedTTS = true
        }
        try ensureCanFallback(generation: gen)
        try await speech.speak(text: fallbackText, languageTag: fallbackTag)
    }

    private func ensureCanFallback(generation gen: UInt64) throws {
        guard gen == generation, !Task.isCancelled else {
            throw SpeechSynthesisError.cancelled
        }
    }

    private func markTTSIfContent(_ phase: DrivePhase) {
        switch phase.kind {
        case .revealL2, .shadowTrack:
            itemUsedTTS = true
            sessionUsedTTS = true
        default:
            break
        }
    }

    private func announcementText(_ announcement: DriveAnnouncement) -> String {
        if case .sessionOutro = announcement {
            return outroText?(cursor?.completedPassCount ?? 0) ?? ""
        }
        return announcementTexts[announcement] ?? ""
    }

    private func elapsedMs() -> Int {
        var total = itemAccumulatedMs
        if let itemSegmentStartedAt {
            total += max(Int(Date().timeIntervalSince(itemSegmentStartedAt) * 1_000), 0)
        }
        return total
    }

    private func resetItemTiming() {
        itemSegmentStartedAt = nil
        itemAccumulatedMs = 0
        itemUsedTTS = false
    }

    private func freezeItemSegment() {
        if let itemSegmentStartedAt {
            itemAccumulatedMs += max(Int(Date().timeIntervalSince(itemSegmentStartedAt) * 1_000), 0)
            self.itemSegmentStartedAt = nil
        }
    }

    private func isFirstPhase(of item: DriveItemRef, at index: Int, in script: DriveScript) -> Bool {
        guard index > 0 else { return true }
        return script.phases[index - 1].item != item
    }

    private func haltPlayback(resetCursor: Bool = true) async {
        freezeItemSegment()
        playTask?.cancel()
        playTask = nil
        speech.stopSpeaking()
        filePlayer.stop()
        if resetCursor {
            cursor = nil
            script = nil
        }
    }

    private func emit(_ event: DriveSequencerEvent) {
        for continuation in continuations.values {
            continuation.yield(event)
        }
    }

    private func removeContinuation(_ id: UUID) {
        continuations[id] = nil
    }

    private func startRecoveryMonitoring() {
        recoveryTask?.cancel()
        recoveryTask = Task {
            await recovery.stop()
            for await event in await recovery.events() {
                await self.handleRecovery(event)
            }
        }
    }

    private func handleRecovery(_ event: RecoveryEvent) async {
        switch event {
        case .interruptionBegan:
            await pause(reason: .interruption)
        case let .interruptionEnded(shouldResume):
            if shouldResume {
                await resume()
            }
        case let .routeChange(oldDeviceUnavailable):
            if oldDeviceUnavailable {
                await pause(reason: .routeChange)
            }
        case .mediaServicesReset:
            speech.resetEngine()
            filePlayer.resetEngine()
            await pause(reason: .mediaServicesReset)
        case .configurationChange:
            break
        }
    }

    public var didUseTTSFallback: Bool { sessionUsedTTS }
}
