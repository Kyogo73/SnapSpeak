import Foundation
import SRSKit
import Testing

@Test func compositionQualityTable() {
    let engine = SRSEngine()
    #expect(engine.qualityForComposition(pass: false, latencyMs: 1000, usedHint: false, confidence: 0.9, skipped: true) == .blackout)
    #expect(engine.qualityForComposition(pass: false, latencyMs: 1000, usedHint: false, confidence: 0.9) == .fail)
    #expect(engine.qualityForComposition(pass: true, latencyMs: 12_000, usedHint: false, confidence: 0.9) == .pass)
    #expect(engine.qualityForComposition(pass: true, latencyMs: 8_000, usedHint: false, confidence: 0.9) == .good)
    #expect(engine.qualityForComposition(pass: true, latencyMs: 3_000, usedHint: false, confidence: 0.9) == .easy)
    #expect(engine.qualityForComposition(pass: true, latencyMs: 3_000, usedHint: true, confidence: 0.9) == .pass)
    #expect(engine.qualityForComposition(pass: true, latencyMs: 3_000, usedHint: false, confidence: 0.1) == nil)
    // Typed input has no ASR confidence; nil must not suppress a grade.
    #expect(engine.qualityForComposition(pass: true, latencyMs: 3_000, usedHint: false, confidence: nil) == .easy)
}

@Test func shadowingQualityTable() {
    let engine = SRSEngine()

    func snapshot(
        rate: Double,
        delay: Int?,
        granularity: ShadowingDelayGranularity = .word,
        minConfidence: Double? = 0.9,
        meanConfidence: Double? = 0.9,
        simultaneous: Bool = true
    ) -> ShadowingScoreSnapshot {
        ShadowingScoreSnapshot(
            scriptMatchRate: rate,
            delayMsMedian: delay,
            delayGranularity: granularity,
            minConfidence: minConfidence,
            meanConfidence: meanConfidence,
            simultaneousPlayAndRecord: simultaneous
        )
    }

    #expect(engine.qualityForShadowing(score: snapshot(rate: 0.3, delay: 100)) == .fail)
    #expect(engine.qualityForShadowing(score: snapshot(rate: 0.5, delay: 100)) == .hard)
    #expect(engine.qualityForShadowing(score: snapshot(rate: 0.7, delay: 900)) == .pass)
    #expect(engine.qualityForShadowing(score: snapshot(rate: 0.7, delay: 100)) == .good)
    #expect(engine.qualityForShadowing(score: snapshot(rate: 0.9, delay: 900)) == .good)
    #expect(engine.qualityForShadowing(score: snapshot(rate: 0.9, delay: 100)) == .easy)
    #expect(engine.qualityForShadowing(score: snapshot(rate: 0.9, delay: 900, granularity: .sentenceApproximate)) == .easy)
    #expect(engine.qualityForShadowing(score: snapshot(rate: 0.9, delay: 100, simultaneous: false)) == nil)
    #expect(engine.qualityForShadowing(score: snapshot(rate: 0.9, delay: 100, minConfidence: 0.1)) == nil)
    #expect(engine.qualityForShadowing(score: snapshot(
        rate: 0.9,
        delay: 100,
        minConfidence: nil,
        meanConfidence: nil
    )) == nil)
    #expect(engine.qualityForShadowing(score: snapshot(
        rate: 0.9,
        delay: 100,
        minConfidence: 0.9,
        meanConfidence: nil
    )) == nil)
}
