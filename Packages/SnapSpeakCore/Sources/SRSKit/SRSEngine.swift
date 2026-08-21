import Foundation
import LanguageKit

public struct SRSEngine: Sendable {
    public var policy: GradingPolicy

    public init(policy: GradingPolicy = .phase1English) {
        self.policy = policy
    }

    public func qualityForComposition(
        pass: Bool,
        latencyMs: Int,
        usedHint: Bool,
        confidence: Double?,
        tokenCount: Int = 0,
        skipped: Bool = false,
        language: BCP47Language? = nil
    ) -> ReviewQuality? {
        let language = language ?? BCP47Language.english
        let band = policy.compositionBand(language: language, tokenCount: tokenCount)
        if let confidence, let band, confidence < band.minConfidence {
            return nil
        }
        if skipped { return .blackout }
        if !pass { return .fail }

        let fast = band?.fastLatencyMs ?? 4_000
        let slow = band?.slowLatencyMs ?? 12_000
        var quality: ReviewQuality
        if latencyMs <= fast {
            quality = .easy
        } else if latencyMs >= slow {
            quality = .pass
        } else {
            quality = .good
        }
        if usedHint, quality.rawValue > ReviewQuality.pass.rawValue {
            quality = .pass
        }
        return quality
    }

    public func qualityForShadowing(score: ShadowingScoreSnapshot) -> ReviewQuality? {
        let thresholds = policy.shadowing
        if !score.simultaneousPlayAndRecord { return nil }
        if let min = score.minConfidence, min < thresholds.minConfidence { return nil }
        if let mean = score.meanConfidence, mean < thresholds.minConfidence { return nil }

        let rate = score.scriptMatchRate
        if rate < thresholds.matchRateVeryLow { return .fail }
        if rate < thresholds.matchRateLow { return .hard }

        let delayForQ: Int?
        if score.delayGranularity == .word {
            delayForQ = score.delayMsMedian
        } else {
            delayForQ = nil
        }
        let delayIsLarge = (delayForQ ?? 0) >= thresholds.largeDelayMs && delayForQ != nil

        if rate < thresholds.matchRateHigh {
            return delayIsLarge ? .pass : .good
        }
        return delayIsLarge ? .good : .easy
    }

    public func fold(
        events: [ReviewEventDTO],
        now: Date,
        calendar: Calendar,
        dayBoundaryHour: Int
    ) -> SRSState {
        var state = SRSState.initial(now: now)
        var seen: Set<UUID> = []
        let ordered = Self.ordered(events)
        for event in ordered {
            if seen.contains(event.id) { continue }
            seen.insert(event.id)
            guard let quality = ReviewQuality(rawValue: event.quality) else { continue }
            state = SM2.apply(
                state: state,
                quality: quality,
                reviewedAt: event.reviewedAt,
                calendar: calendar,
                dayBoundaryHour: dayBoundaryHour
            )
            state.contentRevision = event.contentRevision
        }
        return state
    }

    /// Synced events by `serverRevision`, then unsynced by `clientSeq`.
    public static func ordered(_ events: [ReviewEventDTO]) -> [ReviewEventDTO] {
        let synced = events.filter { $0.serverRevision != nil }
            .sorted { lhs, rhs in
                if lhs.serverRevision != rhs.serverRevision {
                    return (lhs.serverRevision ?? 0) < (rhs.serverRevision ?? 0)
                }
                return lhs.clientSeq < rhs.clientSeq
            }
        let unsynced = events.filter { $0.serverRevision == nil }
            .sorted { $0.clientSeq < $1.clientSeq }
        return synced + unsynced
    }
}
