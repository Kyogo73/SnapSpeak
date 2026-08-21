import ContentCore
import ScoringKit
import SpeechKit
import SRSKit

enum ScoreMapping {
    static func asrSegments(_ segments: [SpeechTranscriptSegment]) -> [ASRSegment] {
        segments.map { segment in
            ASRSegment(
                text: segment.text,
                timestamp: segment.timestamp,
                duration: segment.duration,
                confidence: segment.confidence
            )
        }
    }

    static func snapshot(_ score: ShadowingScore) -> ShadowingScoreSnapshot {
        ShadowingScoreSnapshot(
            scriptMatchRate: score.scriptMatchRate,
            delayMsMedian: score.delayMsMedian,
            delayGranularity: delayGranularity(score.delayGranularity),
            minConfidence: score.minConfidence,
            meanConfidence: score.meanConfidence,
            simultaneousPlayAndRecord: score.simultaneousPlayAndRecord
        )
    }

    static func wordTimings(_ timings: [WordTiming]?) -> [WordTimingDTO]? {
        timings?.map { WordTimingDTO(startMs: $0.startMs, endMs: $0.endMs, text: $0.text) }
    }

    static func captions(_ segments: [CaptionSegment]?) -> [CaptionSegmentDTO]? {
        segments?.map { CaptionSegmentDTO(startMs: $0.startMs, endMs: $0.endMs, text: $0.text) }
    }

    private static func delayGranularity(_ value: DelayGranularity) -> ShadowingDelayGranularity {
        switch value {
        case .word: return .word
        case .sentenceApproximate: return .sentenceApproximate
        case .unavailable: return .unavailable
        }
    }
}
