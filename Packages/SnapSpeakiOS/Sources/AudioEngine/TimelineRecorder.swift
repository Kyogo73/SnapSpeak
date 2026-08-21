import AVFoundation
import Foundation
import ScoringKit

/// Records `PlaybackTimeline` events against a shared host-time clock.
public final class TimelineRecorder: @unchecked Sendable {
    private var events: [TimelineEvent] = []
    private var recordingStartHostTime: TimeInterval = 0

    public init() {}

    public func nowHostSeconds() -> TimeInterval {
        AVAudioTime.seconds(forHostTime: mach_absolute_time())
    }

    @discardableResult
    public func resetAndMarkRecordingStart() -> TimeInterval {
        reset()
        let host = nowHostSeconds()
        recordingStartHostTime = host
        return host
    }

    public func reset() {
        events = []
        recordingStartHostTime = 0
    }

    public func record(
        kind: TimelineEventKind,
        hostTime: TimeInterval,
        sourcePositionSeconds: Double,
        presentedRate: Float
    ) {
        events.append(
            TimelineEvent(
                kind: kind,
                hostTime: hostTime,
                sourcePositionSeconds: sourcePositionSeconds,
                presentedRate: presentedRate
            )
        )
    }

    public func currentSourcePosition() -> Double? {
        PlaybackTimeline(
            events: events,
            recordingStartHostTime: recordingStartHostTime
        ).presentedSourcePosition(atHostTime: nowHostSeconds())
    }

    public func snapshot() -> PlaybackTimeline {
        PlaybackTimeline(events: events, recordingStartHostTime: recordingStartHostTime)
    }
}
