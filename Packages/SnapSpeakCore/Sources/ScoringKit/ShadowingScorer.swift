import Foundation
import LanguageKit

public struct ShadowingScorer: Sendable {
    private let tokenizer: WhitespaceTokenizer

    public init(tokenizer: WhitespaceTokenizer = WhitespaceTokenizer()) {
        self.tokenizer = tokenizer
    }

    public func score(
        referenceScript: String,
        language: BCP47Language,
        asrSegments: [ASRSegment],
        timeline: PlaybackTimeline?,
        wordTimings: [WordTimingDTO]?,
        captionSegments: [CaptionSegmentDTO]?,
        audioRoute: AudioRouteSnapshot,
        playbackRate: Float,
        simultaneousPlayAndRecord: Bool,
        utteranceDurationSeconds: Double? = nil
    ) -> ShadowingScore {
        let reference = tokenizer.tokenize(referenceScript, language: language)
        var hypothesis: [Token] = []
        for segment in asrSegments {
            let pieces = tokenizer.tokenize(segment.text, language: language)
            let startMs = Int((segment.timestamp * 1000.0).rounded())
            let endMs = Int(((segment.timestamp + segment.duration) * 1000.0).rounded())
            for piece in pieces {
                hypothesis.append(
                    Token(surface: piece.surface, normalized: piece.normalized, startMs: startMs, endMs: endMs)
                )
            }
        }

        let refNorm = reference.map(\.normalized)
        let hypNorm = hypothesis.map(\.normalized)
        let ops = Aligner.align(reference: refNorm, hypothesis: hypNorm)
        let equalCount = ops.reduce(0) { count, op in
            if case .equal = op { return count + 1 }
            return count
        }
        let n = reference.count
        let m = hypothesis.count
        let scriptMatchRate = ScoreMetrics.scriptMatchRate(equalCount: equalCount, referenceCount: n)
        let precision = ScoreMetrics.precision(equalCount: equalCount, hypothesisCount: m)
        let recall = ScoreMetrics.recall(equalCount: equalCount, referenceCount: n)
        let hesitation = HesitationDetector.detect(ops: ops, hypothesis: hypNorm, language: language)

        let duration: Double
        if let utteranceDurationSeconds {
            duration = utteranceDurationSeconds
        } else if let first = asrSegments.first, let last = asrSegments.last {
            duration = max(0, (last.timestamp + last.duration) - first.timestamp)
        } else {
            duration = 0
        }
        let wpm = WPMCalculator.wordsPerMinute(tokenCount: m, utteranceSeconds: duration)

        let delay = DelayCalculator.calculate(
            ops: ops,
            reference: reference,
            hypothesis: hypothesis,
            asrSegments: asrSegments,
            timeline: timeline,
            wordTimings: wordTimings,
            captionSegments: captionSegments,
            language: language
        )

        let confidences = asrSegments.map(\.confidence)
        let mean = confidences.isEmpty ? nil : confidences.reduce(0, +) / Double(confidences.count)
        let minC = confidences.min()

        return ShadowingScore(
            payloadSchemaVersion: 1,
            scriptMatchRate: scriptMatchRate,
            precision: precision,
            recall: recall,
            omissions: hesitation.omissions,
            hesitations: hesitation.hesitations,
            substitutions: hesitation.substitutions,
            wpm: wpm,
            delayMsMedian: delay.delayMsMedian,
            delayGranularity: delay.granularity,
            asrOnDevice: true,
            meanConfidence: mean,
            minConfidence: minC,
            audioRoute: audioRoute,
            playbackRate: playbackRate,
            simultaneousPlayAndRecord: simultaneousPlayAndRecord
        )
    }
}
