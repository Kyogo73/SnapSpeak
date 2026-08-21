import Analytics
import AVFoundation
import Foundation
import ScoringKit

public enum AudioEngineState: String, Sendable, Equatable {
    case idle
    case previewing
    case shadowingLive
    case recordOnly
}

public struct ShadowingSessionResult: Sendable, Equatable {
    public var recordingURL: URL?
    public var timeline: PlaybackTimeline
    public var route: AudioRouteSnapshot
    public var simultaneousPlayAndRecord: Bool
    public var voiceProcessingEnabled: Bool
    public var wasDegraded: Bool

    public init(
        recordingURL: URL?,
        timeline: PlaybackTimeline,
        route: AudioRouteSnapshot,
        simultaneousPlayAndRecord: Bool,
        voiceProcessingEnabled: Bool,
        wasDegraded: Bool
    ) {
        self.recordingURL = recordingURL
        self.timeline = timeline
        self.route = route
        self.simultaneousPlayAndRecord = simultaneousPlayAndRecord
        self.voiceProcessingEnabled = voiceProcessingEnabled
        self.wasDegraded = wasDegraded
    }
}

/// Owns the AVAudioEngine graph. Always stop → rebuild on session or route changes.
public actor AudioEngineActor {
    public private(set) var state: AudioEngineState = .idle
    public private(set) var lastDecision: RouteDecision = RoutePolicy.idleDecision
    public private(set) var lastVoiceProcessing = VoiceProcessingResult.disabled

    private let session: AudioSessionConfigurator
    private let analytics: any AnalyticsClient
    private let graph: PlayerGraph
    private let timeline = TimelineRecorder()
    private let recovery = RecoveryObserver()
    private var recordingURL: URL?
    private var currentRate: Float = 1.0
    private var recoveryTask: Task<Void, Never>?

    public init(
        session: AudioSessionConfigurator = AudioSessionConfigurator(),
        analytics: any AnalyticsClient
    ) {
        self.session = session
        self.analytics = analytics
        self.graph = PlayerGraph()
    }

    public func startPreview(fileURL: URL, rate: Float) async throws {
        try await teardownToIdle()
        lastDecision = RoutePolicy.decide()
        try session.activatePreview()
        currentRate = PlayerGraph.clampedRate(rate)
        try graph.attachPlayback(rate: currentRate)
        timeline.reset()
        let host = timeline.nowHostSeconds()
        timeline.record(
            kind: .start,
            hostTime: host,
            sourcePositionSeconds: 0,
            presentedRate: currentRate
        )
        try graph.scheduleAndPlay(fileURL: fileURL, atHostSeconds: host)
        try graph.startEngine()
        state = .previewing
        startRecoveryMonitoring()
        _ = analytics
    }

    public func startShadowingLive(fileURL: URL, recordingURL: URL, rate: Float) async throws {
        try await teardownToIdle()
        lastDecision = RoutePolicy.decide()
        currentRate = PlayerGraph.clampedRate(rate)
        try session.activatePlayAndRecord(
            defaultToSpeaker: lastDecision.defaultToSpeaker,
            allowBluetoothHFP: lastDecision.allowBluetoothHFP
        )
        try graph.attachPlayback(rate: currentRate)
        lastVoiceProcessing = VoiceProcessing.enable(on: graph.engine)
        if lastDecision.requiresVoiceProcessing, !lastVoiceProcessing.enabled {
            lastDecision = lastDecision.degradedDisablingSimultaneous()
        }
        let host = timeline.resetAndMarkRecordingStart()
        try graph.installInputTap(to: recordingURL)
        self.recordingURL = recordingURL
        timeline.record(
            kind: .start,
            hostTime: host,
            sourcePositionSeconds: 0,
            presentedRate: currentRate
        )
        try graph.scheduleAndPlay(fileURL: fileURL, atHostSeconds: host)
        try graph.startEngine()
        state = .shadowingLive
        startRecoveryMonitoring()
    }

    public func startRecordOnly(recordingURL: URL) async throws {
        try await teardownToIdle()
        lastDecision = RoutePolicy.decide().degradedDisablingSimultaneous()
        try session.activatePlayAndRecord(
            defaultToSpeaker: lastDecision.defaultToSpeaker,
            allowBluetoothHFP: false
        )
        try graph.attachRecordOnly()
        lastVoiceProcessing = VoiceProcessing.enable(on: graph.engine)
        let host = timeline.resetAndMarkRecordingStart()
        try graph.installInputTap(to: recordingURL)
        self.recordingURL = recordingURL
        timeline.record(
            kind: .start,
            hostTime: host,
            sourcePositionSeconds: 0,
            presentedRate: 0
        )
        try graph.startEngine()
        state = .recordOnly
        startRecoveryMonitoring()
    }

    public func setRate(_ rate: Float) {
        guard state == .previewing || state == .shadowingLive else { return }
        currentRate = PlayerGraph.clampedRate(rate)
        let source = timeline.currentSourcePosition() ?? 0
        graph.setRate(currentRate)
        timeline.record(
            kind: .setRate,
            hostTime: timeline.nowHostSeconds(),
            sourcePositionSeconds: source,
            presentedRate: currentRate
        )
    }

    public func seek(toSourceSeconds source: Double) {
        guard state == .previewing || state == .shadowingLive else { return }
        timeline.record(
            kind: .seek,
            hostTime: timeline.nowHostSeconds(),
            sourcePositionSeconds: source,
            presentedRate: currentRate
        )
    }

    public func pause() {
        guard state != .idle else { return }
        graph.pause()
        timeline.record(
            kind: .pause,
            hostTime: timeline.nowHostSeconds(),
            sourcePositionSeconds: timeline.currentSourcePosition() ?? 0,
            presentedRate: 0
        )
    }

    public func resume() throws {
        guard state != .idle else { return }
        try graph.startEngine()
        graph.resume()
        timeline.record(
            kind: .resume,
            hostTime: timeline.nowHostSeconds(),
            sourcePositionSeconds: timeline.currentSourcePosition() ?? 0,
            presentedRate: state == .recordOnly ? 0 : currentRate
        )
    }

    @discardableResult
    public func stop() async -> ShadowingSessionResult {
        let source = timeline.currentSourcePosition() ?? 0
        timeline.record(
            kind: .stop,
            hostTime: timeline.nowHostSeconds(),
            sourcePositionSeconds: source,
            presentedRate: 0
        )
        graph.teardown()
        try? session.deactivate()
        recoveryTask?.cancel()
        recoveryTask = nil
        await recovery.stop()
        let result = ShadowingSessionResult(
            recordingURL: recordingURL,
            timeline: timeline.snapshot(),
            route: lastDecision.snapshot(voiceProcessingEnabled: lastVoiceProcessing.enabled),
            simultaneousPlayAndRecord: state == .shadowingLive && lastDecision.allowSimultaneousScoring,
            voiceProcessingEnabled: lastVoiceProcessing.enabled,
            wasDegraded: lastDecision.isDegraded || state == .recordOnly
        )
        recordingURL = nil
        state = .idle
        return result
    }

    public func handleRecovery(_ event: RecoveryEvent) async {
        switch event {
        case .interruptionBegan:
            pause()
        case .interruptionEnded(shouldResume: _):
            graph.teardown()
            try? session.deactivate()
            state = .idle
        case .routeChange, .mediaServicesReset, .configurationChange:
            _ = await stop()
        }
    }

    private func teardownToIdle() async throws {
        if state != .idle {
            _ = await stop()
        }
        graph.teardown()
        timeline.reset()
    }

    private func startRecoveryMonitoring() {
        recoveryTask?.cancel()
        recoveryTask = Task {
            await recovery.stop()
            for await event in await recovery.events() {
                await handleRecovery(event)
            }
        }
    }
}
