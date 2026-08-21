import Foundation
import LanguageKit

/// Language × token-count × confidence thresholds. Values are data, not hardcoded branches.
public struct GradingPolicy: Sendable, Equatable {
    public struct CompositionBand: Sendable, Equatable {
        public var language: String
        public var maxTokenCountExclusive: Int
        public var fastLatencyMs: Int
        public var slowLatencyMs: Int
        public var minConfidence: Double

        public init(
            language: String,
            maxTokenCountExclusive: Int,
            fastLatencyMs: Int,
            slowLatencyMs: Int,
            minConfidence: Double
        ) {
            self.language = language
            self.maxTokenCountExclusive = maxTokenCountExclusive
            self.fastLatencyMs = fastLatencyMs
            self.slowLatencyMs = slowLatencyMs
            self.minConfidence = minConfidence
        }
    }

    public struct ShadowingThresholds: Sendable, Equatable {
        public var largeDelayMs: Int
        public var minConfidence: Double
        public var matchRateVeryLow: Double
        public var matchRateLow: Double
        public var matchRateHigh: Double

        public init(
            largeDelayMs: Int,
            minConfidence: Double,
            matchRateVeryLow: Double,
            matchRateLow: Double,
            matchRateHigh: Double
        ) {
            self.largeDelayMs = largeDelayMs
            self.minConfidence = minConfidence
            self.matchRateVeryLow = matchRateVeryLow
            self.matchRateLow = matchRateLow
            self.matchRateHigh = matchRateHigh
        }
    }

    public var compositionBands: [CompositionBand]
    public var shadowing: ShadowingThresholds

    public init(compositionBands: [CompositionBand], shadowing: ShadowingThresholds) {
        self.compositionBands = compositionBands
        self.shadowing = shadowing
    }

    /// Architecture §6.3 Phase 1 provisional English values.
    public static let phase1English = GradingPolicy(
        compositionBands: [
            CompositionBand(
                language: "en",
                maxTokenCountExclusive: 12,
                fastLatencyMs: 4_000,
                slowLatencyMs: 12_000,
                minConfidence: 0.3
            ),
        ],
        shadowing: ShadowingThresholds(
            largeDelayMs: 800,
            minConfidence: 0.3,
            matchRateVeryLow: 0.4,
            matchRateLow: 0.6,
            matchRateHigh: 0.8
        )
    )

    public func compositionBand(language: BCP47Language, tokenCount: Int) -> CompositionBand? {
        compositionBands.first { band in
            band.language == language.languageSubtag && tokenCount < band.maxTokenCountExclusive
        } ?? compositionBands.first { $0.language == language.languageSubtag }
            ?? compositionBands.first
    }
}

/// Delay granularity copied as a scoring-input enum so SRSKit does not depend on ScoringKit.
public enum ShadowingDelayGranularity: String, Sendable, Codable, Equatable {
    case word
    case sentenceApproximate
    case unavailable
}

/// Fields from a shadowing score that participate in q. Avoids SRSKit → ScoringKit.
public struct ShadowingScoreSnapshot: Sendable, Equatable {
    public var scriptMatchRate: Double
    public var delayMsMedian: Int?
    public var delayGranularity: ShadowingDelayGranularity
    public var minConfidence: Double?
    public var meanConfidence: Double?
    public var simultaneousPlayAndRecord: Bool

    public init(
        scriptMatchRate: Double,
        delayMsMedian: Int?,
        delayGranularity: ShadowingDelayGranularity,
        minConfidence: Double?,
        meanConfidence: Double?,
        simultaneousPlayAndRecord: Bool
    ) {
        self.scriptMatchRate = scriptMatchRate
        self.delayMsMedian = delayMsMedian
        self.delayGranularity = delayGranularity
        self.minConfidence = minConfidence
        self.meanConfidence = meanConfidence
        self.simultaneousPlayAndRecord = simultaneousPlayAndRecord
    }
}
