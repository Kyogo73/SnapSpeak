import AVFoundation
import DriveKit
import Foundation

/// `DriveScript` を 1 フェーズずつ実行する。進行判断は `DriveCursor` に委譲する。
public actor DriveSequencer: DriveSequencing {
    private let speech: any SpeechSynthesizing
    private let filePlayer: any PhaseFilePlaying
    private let clock: any DriveClocking
    private let session: AudioSessionConfigurator
    private var assets: any DriveAssetResolving
    private let recovery = RecoveryObserver()

    private var cursor: DriveCursor?
    private var script: DriveScript?
    private var announcementTexts: [DriveAnnouncement: String] = [:]
    private var outroText: (@Sendable (Int) -> String)?
    private var generation: UInt64 = 0
    private var playTask: Task<Void, Never>?
    private var recoveryTask: Task<Void, Never>?
    private var itemStartedAt: Date?
    private var itemUsedTTS = false
    private var sessionUsedTTS = false
    private var continuations: [UUID: AsyncStream<DriveSequencerEvent>.Continuation] = [:]

    public init(
        speech: any SpeechSynthesizing,
        filePlayer: any PhaseFilePlaying,
        clock: any DriveClocking = ContinuousClockSleeper(),
        session: AudioSessionConfigurator = AudioSessionConfigurator(),
        assets: any DriveAssetResolving = EmptyAssetResolver()
    ) {
        self.speech = speech
        self.filePlayer = filePlayer
        self.clock = clock
        self.session = session
        self.assets = assets
    }

    public func events() -> AsyncStream<DriveSequencerEvent> {
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
        var next = DriveCursor(script: script)
        let outputs = next.start()
        cursor = next
        startRecoveryMonitoring()
        try? session.activatePreview()
        await handle(outputs, generation: generation)
    }

    public func pause() async {
        await pause(reason: .user)
    }

    public func resume() async {
        generation += 1
        let gen = generation
        do {
            try session.activatePreview()
        } catch {
            emit(.paused(reason: .audioSessionFailure))
            return
        }
        guard var cursor else { return }
        let outputs = cursor.apply(.resume)
        self.cursor = cursor
        emit(.resumed)
        await handle(outputs, generation: gen)
    }

    public func skipForward() async {
        generation += 1
        let gen = generation
        await haltPlayback(resetCursor: false)
        guard var cursor else { return }
        let outputs = cursor.apply(.skipToNextItem)
        self.cursor = cursor
        await handle(outputs, generation: gen)
    }

    public func skipBackward() async {
        generation += 1
        let gen = generation
        await haltPlayback(resetCursor: false)
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

    private func pause(reason: DrivePauseReason) async {
        generation += 1
        await haltPlayback(resetCursor: false)
        guard var cursor else { return }
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
                let elapsed = elapsedMs()
                emit(.itemCompleted(ref, usedTTSFallback: itemUsedTTS, elapsedMs: elapsed))
                itemStartedAt = nil
                itemUsedTTS = false
            case let .finished(endedByUser):
                emit(.finished(endedByUser: endedByUser, completedCount: cursor?.completedPassCount ?? 0))
                await recovery.stop()
            }
        }
    }

    private func playPhase(_ index: Int, generation gen: UInt64) async {
        guard gen == generation, let script, script.phases.indices.contains(index) else { return }
        let phase = script.phases[index]
        if let item = phase.item, itemStartedAt == nil {
            itemStartedAt = Date()
            itemUsedTTS = false
        }
        emit(.phaseChanged(kind: phase.kind, itemRef: phase.item))
        do {
            try await render(phase)
        } catch SpeechSynthesisError.voiceUnavailable {
            guard gen == generation, var cursor else { return }
            if let item = phase.item {
                emit(.itemSkipped(item))
            }
            let outputs = cursor.apply(.skipToNextItem)
            self.cursor = cursor
            await handle(outputs, generation: gen)
            return
        } catch {
            return
        }
        guard gen == generation, var cursor else { return }
        let outputs = cursor.apply(.phaseFinished)
        self.cursor = cursor
        await handle(outputs, generation: gen)
    }

    private func render(_ phase: DrivePhase) async throws {
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
                fallbackTag: fallbackTag
            )
        case .silence:
            await clock.sleep(milliseconds: phase.estimatedDurationMs)
        }
    }

    private func playFileOrFallback(
        courseId: String,
        relativePath: String,
        fallbackText: String,
        fallbackTag: String
    ) async throws {
        if let url = assets.fileURL(courseId: courseId, relativePath: relativePath) {
            do {
                try await filePlayer.play(url: url)
                return
            } catch {
                itemUsedTTS = true
                sessionUsedTTS = true
            }
        } else {
            itemUsedTTS = true
            sessionUsedTTS = true
        }
        try await speech.speak(text: fallbackText, languageTag: fallbackTag)
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
        guard let itemStartedAt else { return 0 }
        return max(Int(Date().timeIntervalSince(itemStartedAt) * 1_000), 0)
    }

    private func haltPlayback(resetCursor: Bool = true) async {
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
        case .routeChange:
            await pause(reason: .routeChange)
        case .mediaServicesReset:
            speech.stopSpeaking()
            filePlayer.stop()
            await pause(reason: .mediaServicesReset)
        case .configurationChange:
            break
        }
    }

    public var didUseTTSFallback: Bool { sessionUsedTTS }
}
