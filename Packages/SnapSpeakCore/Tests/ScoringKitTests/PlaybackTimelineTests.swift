import Foundation
import ScoringKit
import Testing

@Test func constantRateThenSlowdown() {
    let timeline = PlaybackTimeline(events: [
        TimelineEvent(kind: .start, hostTime: 0, sourcePositionSeconds: 0, presentedRate: 1.0),
        TimelineEvent(kind: .setRate, hostTime: 2, sourcePositionSeconds: 2.0, presentedRate: 0.75),
    ])
    #expect(timeline.presentedSourcePosition(atHostTime: 1) == 1.0)
    #expect(timeline.presentedSourcePosition(atHostTime: 2) == 2.0)
    let atSix = timeline.presentedSourcePosition(atHostTime: 6)
    #expect(atSix != nil)
    #expect(abs((atSix ?? 0) - 5.0) < 0.000_001)
}

@Test func seekJumpsSourcePosition() {
    let timeline = PlaybackTimeline(events: [
        TimelineEvent(kind: .start, hostTime: 0, sourcePositionSeconds: 0, presentedRate: 1.0),
        TimelineEvent(kind: .seek, hostTime: 3, sourcePositionSeconds: 1.0, presentedRate: 1.0),
    ])
    #expect(timeline.presentedSourcePosition(atHostTime: 3) == 1.0)
    #expect(timeline.presentedSourcePosition(atHostTime: 4) == 2.0)
}

@Test func loopRestartsSource() {
    let timeline = PlaybackTimeline(events: [
        TimelineEvent(kind: .start, hostTime: 0, sourcePositionSeconds: 0, presentedRate: 1.0),
        TimelineEvent(kind: .loop, hostTime: 4, sourcePositionSeconds: 1.0, presentedRate: 1.0),
    ])
    #expect(timeline.presentedSourcePosition(atHostTime: 4) == 1.0)
    #expect(timeline.presentedSourcePosition(atHostTime: 5) == 2.0)
}

@Test func pauseFreezesThenResumeContinues() {
    let timeline = PlaybackTimeline(events: [
        TimelineEvent(kind: .start, hostTime: 0, sourcePositionSeconds: 0, presentedRate: 1.0),
        TimelineEvent(kind: .pause, hostTime: 2, sourcePositionSeconds: 2.0, presentedRate: 0),
        TimelineEvent(kind: .resume, hostTime: 5, sourcePositionSeconds: 2.0, presentedRate: 1.0),
    ])
    #expect(timeline.presentedSourcePosition(atHostTime: 3) == 2.0)
    #expect(timeline.presentedSourcePosition(atHostTime: 6) == 3.0)
}

@Test func unknownHostBeforeStartIsNil() {
    let timeline = PlaybackTimeline(events: [
        TimelineEvent(kind: .start, hostTime: 1, sourcePositionSeconds: 0, presentedRate: 1.0),
    ])
    #expect(timeline.presentedSourcePosition(atHostTime: 0) == nil)
}
