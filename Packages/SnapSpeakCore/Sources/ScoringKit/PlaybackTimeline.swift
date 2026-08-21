import Foundation

public enum TimelineEventKind: String, Sendable, Codable, Equatable {
    case start
    case pause
    case resume
    case setRate
    case seek
    case loop
    case stop
}

public struct TimelineEvent: Sendable, Equatable {
    public var kind: TimelineEventKind
    /// Host time in seconds (same clock as recording start).
    public var hostTime: TimeInterval
    /// Original-speed source position in seconds at this instant.
    public var sourcePositionSeconds: Double
    /// Presentation rate in effect *after* this event (0 while paused).
    public var presentedRate: Float

    public init(
        kind: TimelineEventKind,
        hostTime: TimeInterval,
        sourcePositionSeconds: Double,
        presentedRate: Float
    ) {
        self.kind = kind
        self.hostTime = hostTime
        self.sourcePositionSeconds = sourcePositionSeconds
        self.presentedRate = presentedRate
    }
}

public struct PlaybackTimeline: Sendable, Equatable {
    public var events: [TimelineEvent]
    public var recordingStartHostTime: TimeInterval

    public init(events: [TimelineEvent], recordingStartHostTime: TimeInterval = 0) {
        self.events = events
        self.recordingStartHostTime = recordingStartHostTime
    }

    /// Single implementation: original-speed source position that was presented at `hostTime`.
    public func presentedSourcePosition(atHostTime hostTime: TimeInterval) -> Double? {
        guard let event = lastEvent(atOrBefore: hostTime) else { return nil }
        if event.kind == .stop || event.kind == .pause || event.presentedRate == 0 {
            return event.sourcePositionSeconds
        }
        let dt = hostTime - event.hostTime
        return event.sourcePositionSeconds + dt * Double(event.presentedRate)
    }

    /// Host time when `sourcePosition` was last presented at or before `hostTime`.
    public func hostTime(forSourcePosition sourcePosition: Double, atOrBefore hostTime: TimeInterval) -> TimeInterval? {
        var lastHit: TimeInterval?
        let relevant = events.filter { $0.hostTime <= hostTime }
        guard !relevant.isEmpty else { return nil }

        for (index, event) in relevant.enumerated() {
            let nextHost: TimeInterval
            if index + 1 < relevant.count {
                nextHost = relevant[index + 1].hostTime
            } else {
                nextHost = hostTime
            }
            if event.kind == .seek || event.kind == .loop || event.kind == .start {
                if abs(event.sourcePositionSeconds - sourcePosition) < 0.000_001 {
                    lastHit = event.hostTime
                }
            }
            let rate = Double(event.presentedRate)
            if rate > 0, event.kind != .stop, event.kind != .pause {
                let start = event.sourcePositionSeconds
                let end = start + (nextHost - event.hostTime) * rate
                let lo = min(start, end)
                let hi = max(start, end)
                if sourcePosition >= lo - 0.000_001 && sourcePosition <= hi + 0.000_001 {
                    let hit = event.hostTime + (sourcePosition - start) / rate
                    if hit >= event.hostTime - 0.000_001 && hit <= nextHost + 0.000_001 {
                        lastHit = hit
                    }
                }
            }
        }
        return lastHit
    }

    private func lastEvent(atOrBefore hostTime: TimeInterval) -> TimelineEvent? {
        events.last { $0.hostTime <= hostTime }
    }
}
