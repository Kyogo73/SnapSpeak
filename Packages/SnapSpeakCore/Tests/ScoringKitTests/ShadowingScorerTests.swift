import Foundation
import LanguageKit
import ScoringKit
import Testing

@Test func scorerGoldenPerfectMatch() throws {
    let language = try BCP47Language("en")
    let scorer = ShadowingScorer()
    let route = AudioRouteSnapshot(
        inputPortName: "HeadsetMicrophone",
        outputPortName: "Headphones",
        isHFP: false,
        voiceProcessingEnabled: true
    )
    let score = scorer.score(
        referenceScript: "Hi I am late",
        language: language,
        asrSegments: [
            ASRSegment(text: "Hi I am late", timestamp: 0.1, duration: 1.9, confidence: 0.92),
        ],
        timeline: PlaybackTimeline(events: [
            TimelineEvent(kind: .start, hostTime: 0, sourcePositionSeconds: 0, presentedRate: 1.0),
        ]),
        wordTimings: [
            WordTimingDTO(startMs: 0, endMs: 200, text: "Hi"),
            WordTimingDTO(startMs: 250, endMs: 400, text: "I"),
            WordTimingDTO(startMs: 420, endMs: 700, text: "am"),
            WordTimingDTO(startMs: 750, endMs: 1100, text: "late"),
        ],
        captionSegments: [
            CaptionSegmentDTO(startMs: 0, endMs: 2000, text: "Hi I am late"),
        ],
        audioRoute: route,
        playbackRate: 1.0,
        simultaneousPlayAndRecord: true,
        utteranceDurationSeconds: 2.0
    )

    #expect(score.payloadSchemaVersion == 1)
    #expect(score.scriptMatchRate == 1)
    #expect(score.precision == 1)
    #expect(score.recall == 1)
    #expect(score.omissions.isEmpty)
    #expect(score.hesitations == 0)
    #expect(score.substitutions == 0)
    #expect(score.wpm == 120)
    #expect(score.asrOnDevice == true)
    #expect(score.meanConfidence == 0.92)
    #expect(score.minConfidence == 0.92)
    #expect(score.audioRoute == route)
    #expect(score.playbackRate == 1.0)
    #expect(score.simultaneousPlayAndRecord == true)
    #expect(score.delayGranularity == .word)
}

@Test func scorerEmptyHypothesisZeroRate() throws {
    let language = try BCP47Language("en")
    let scorer = ShadowingScorer()
    let score = scorer.score(
        referenceScript: "hello",
        language: language,
        asrSegments: [],
        timeline: nil,
        wordTimings: nil,
        captionSegments: nil,
        audioRoute: AudioRouteSnapshot(
            inputPortName: "Mic",
            outputPortName: "Speaker",
            isHFP: false,
            voiceProcessingEnabled: false
        ),
        playbackRate: 1.0,
        simultaneousPlayAndRecord: false
    )
    #expect(score.scriptMatchRate == 0)
    #expect(score.delayGranularity == .unavailable)
    #expect(score.asrOnDevice == true)
}
