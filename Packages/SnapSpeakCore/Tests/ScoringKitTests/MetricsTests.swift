import Foundation
import ScoringKit
import Testing

@Test func goldenMetrics() {
    // n=4, m=5, equal=3
    let equal = 3
    #expect(ScoreMetrics.scriptMatchRate(equalCount: equal, referenceCount: 4) == 0.75)
    #expect(ScoreMetrics.precision(equalCount: equal, hypothesisCount: 5) == 0.6)
    #expect(ScoreMetrics.recall(equalCount: equal, referenceCount: 4) == 0.75)
}

@Test func zeroDenominatorUsesMaxN1() {
    #expect(ScoreMetrics.scriptMatchRate(equalCount: 0, referenceCount: 0) == 0)
    #expect(ScoreMetrics.precision(equalCount: 0, hypothesisCount: 0) == 0)
    #expect(ScoreMetrics.recall(equalCount: 0, referenceCount: 0) == 0)
}

@Test func perfectMatch() {
    #expect(ScoreMetrics.scriptMatchRate(equalCount: 4, referenceCount: 4) == 1)
    #expect(ScoreMetrics.precision(equalCount: 4, hypothesisCount: 4) == 1)
}
