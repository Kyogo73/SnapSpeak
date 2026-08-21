import Foundation
import LanguageKit

public struct WordTimingDTO: Sendable, Equatable {
    public var startMs: Int
    public var endMs: Int
    public var text: String

    public init(startMs: Int, endMs: Int, text: String) {
        self.startMs = startMs
        self.endMs = endMs
        self.text = text
    }
}

public struct CaptionSegmentDTO: Sendable, Equatable {
    public var startMs: Int
    public var endMs: Int
    public var text: String

    public init(startMs: Int, endMs: Int, text: String) {
        self.startMs = startMs
        self.endMs = endMs
        self.text = text
    }
}

public struct DelayResult: Sendable, Equatable {
    public var delayMsMedian: Int?
    public var granularity: DelayGranularity

    public init(delayMsMedian: Int?, granularity: DelayGranularity) {
        self.delayMsMedian = delayMsMedian
        self.granularity = granularity
    }
}

public enum DelayCalculator: Sendable {
    public static func calculate(
        ops: [AlignmentOp],
        reference: [Token],
        hypothesis: [Token],
        asrSegments: [ASRSegment],
        timeline: PlaybackTimeline?,
        wordTimings: [WordTimingDTO]?,
        captionSegments: [CaptionSegmentDTO]?,
        language: BCP47Language
    ) -> DelayResult {
        guard let timeline else {
            return DelayResult(delayMsMedian: nil, granularity: .unavailable)
        }

        if let wordTimings, !wordTimings.isEmpty {
            let delays = wordDelays(
                ops: ops,
                reference: reference,
                hypothesis: hypothesis,
                timeline: timeline,
                wordTimings: wordTimings,
                language: language
            )
            return DelayResult(delayMsMedian: median(delays), granularity: .word)
        }

        if let captionSegments, !captionSegments.isEmpty {
            let delays = sentenceApproximateDelays(
                asrSegments: asrSegments,
                timeline: timeline,
                captionSegments: captionSegments
            )
            return DelayResult(delayMsMedian: median(delays), granularity: .sentenceApproximate)
        }

        return DelayResult(delayMsMedian: nil, granularity: .unavailable)
    }

    private static func wordDelays(
        ops: [AlignmentOp],
        reference: [Token],
        hypothesis: [Token],
        timeline: PlaybackTimeline,
        wordTimings: [WordTimingDTO],
        language: BCP47Language
    ) -> [Int] {
        let refStartMs = mapTimingsToTokens(reference: reference, wordTimings: wordTimings, language: language)
        var delays: [Int] = []
        for op in ops {
            guard case .equal(let refIndex, let hypIndex) = op else { continue }
            guard let tRefMs = refStartMs[refIndex] else { continue }
            guard let asrStart = hypothesis[hypIndex].startMs else { continue }
            let asrHost = timeline.recordingStartHostTime + Double(asrStart) / 1000.0
            let tRefSeconds = Double(tRefMs) / 1000.0
            if let presentedHost = timeline.hostTime(forSourcePosition: tRefSeconds, atOrBefore: asrHost) {
                let delayMs = Int(((asrHost - presentedHost) * 1000.0).rounded())
                delays.append(delayMs)
            }
        }
        return delays
    }

    private static func sentenceApproximateDelays(
        asrSegments: [ASRSegment],
        timeline: PlaybackTimeline,
        captionSegments: [CaptionSegmentDTO]
    ) -> [Int] {
        var delays: [Int] = []
        for caption in captionSegments {
            let captionStartSec = Double(caption.startMs) / 1000.0
            let matching = asrSegments.filter { segment in
                let host = timeline.recordingStartHostTime + segment.timestamp
                guard let pos = timeline.presentedSourcePosition(atHostTime: host) else { return false }
                let posMs = Int((pos * 1000.0).rounded())
                return posMs >= caption.startMs && posMs < caption.endMs
            }
            guard let first = matching.min(by: { $0.timestamp < $1.timestamp }) else { continue }
            let asrHost = timeline.recordingStartHostTime + first.timestamp
            // Repeat/loop: pick the presentation at or before this ASR instant, not the last one overall.
            guard let presentedHost = timeline.hostTime(
                forSourcePosition: captionStartSec,
                atOrBefore: asrHost
            ) else { continue }
            delays.append(Int(((asrHost - presentedHost) * 1000.0).rounded()))
        }
        return delays
    }

    private static func mapTimingsToTokens(
        reference: [Token],
        wordTimings: [WordTimingDTO],
        language: BCP47Language
    ) -> [Int?] {
        let tokenizer = WhitespaceTokenizer()
        var starts = Array(repeating: Optional<Int>.none, count: reference.count)
        var tokenIndex = 0
        for timing in wordTimings {
            let pieces = tokenizer.tokenize(timing.text, language: language)
            for _ in pieces {
                if tokenIndex < starts.count {
                    starts[tokenIndex] = timing.startMs
                    tokenIndex += 1
                }
            }
        }
        return starts
    }

    private static func median(_ values: [Int]) -> Int? {
        guard !values.isEmpty else { return nil }
        let sorted = values.sorted()
        let mid = sorted.count / 2
        if sorted.count.isMultiple(of: 2) {
            return Int((Double(sorted[mid - 1] + sorted[mid]) / 2.0).rounded())
        }
        return sorted[mid]
    }
}
