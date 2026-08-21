import Foundation
import LanguageKit
import ScoringKit
import Testing

@Test func wordTimingDelayDiffersFromRawStartMsAfterRateChange() throws {
    let language = try BCP47Language("en")
    let tokenizer = WhitespaceTokenizer()
    let reference = tokenizer.tokenize("hello world", language: language)
    // 0.5x from the start: "world" at 2000ms original is presented at host 4.0s.
    let timeline = PlaybackTimeline(events: [
        TimelineEvent(kind: .start, hostTime: 0, sourcePositionSeconds: 0, presentedRate: 0.5),
    ])
    let wordTimings = [
        WordTimingDTO(startMs: 0, endMs: 500, text: "hello"),
        WordTimingDTO(startMs: 2000, endMs: 2600, text: "world"),
    ]
    let hypothesis = [
        Token(surface: "hello", normalized: "hello", startMs: 0),
        Token(surface: "world", normalized: "world", startMs: 4000),
    ]
    let ops = Aligner.align(
        reference: reference.map(\.normalized),
        hypothesis: hypothesis.map(\.normalized)
    )
    let result = DelayCalculator.calculate(
        ops: ops,
        reference: reference,
        hypothesis: hypothesis,
        asrSegments: [
            ASRSegment(text: "hello", timestamp: 0, duration: 0.4, confidence: 0.9),
            ASRSegment(text: "world", timestamp: 4.0, duration: 0.4, confidence: 0.9),
        ],
        timeline: timeline,
        wordTimings: wordTimings,
        captionSegments: nil,
        language: language
    )
    #expect(result.granularity == .word)
    #expect(result.delayMsMedian == 0)
    let rawSubtractionMs = 4000 - 2000
    #expect(result.delayMsMedian != rawSubtractionMs)
}

@Test func sentenceApproximateWithoutWordTimings() throws {
    let language = try BCP47Language("en")
    let tokenizer = WhitespaceTokenizer()
    let reference = tokenizer.tokenize("Hello there", language: language)
    let timeline = PlaybackTimeline(events: [
        TimelineEvent(kind: .start, hostTime: 0, sourcePositionSeconds: 0, presentedRate: 1.0),
    ])
    let captions = [
        CaptionSegmentDTO(startMs: 0, endMs: 2000, text: "Hello there"),
    ]
    let asr = [ASRSegment(text: "Hello there", timestamp: 0.3, duration: 0.8, confidence: 0.9)]
    let ops = Aligner.align(
        reference: reference.map(\.normalized),
        hypothesis: tokenizer.tokenize("Hello there", language: language).map(\.normalized)
    )
    let result = DelayCalculator.calculate(
        ops: ops,
        reference: reference,
        hypothesis: tokenizer.tokenize("Hello there", language: language),
        asrSegments: asr,
        timeline: timeline,
        wordTimings: nil,
        captionSegments: captions,
        language: language
    )
    #expect(result.granularity == .sentenceApproximate)
    #expect(result.delayMsMedian == 300)
}

@Test func missingTimelineIsUnavailable() throws {
    let language = try BCP47Language("en")
    let result = DelayCalculator.calculate(
        ops: [],
        reference: [],
        hypothesis: [],
        asrSegments: [],
        timeline: nil,
        wordTimings: [WordTimingDTO(startMs: 0, endMs: 100, text: "hi")],
        captionSegments: nil,
        language: language
    )
    #expect(result.granularity == .unavailable)
    #expect(result.delayMsMedian == nil)
}
