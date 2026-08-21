import Foundation
import AnalyticsCore
import Testing

@Test func scoreBandBoundaries() {
    #expect(Quantization.scoreBand(0.0) == 0.0)
    #expect(Quantization.scoreBand(0.05) == 0.1)
    #expect(Quantization.scoreBand(0.95) == 1.0)
    #expect(Quantization.scoreBand(1.0) == 1.0)
}

@Test func durationBands() {
    #expect(Quantization.durationBand(ms: 0) == "0-5s")
    #expect(Quantization.durationBand(ms: 14_999) == "5-15s")
    #expect(Quantization.durationBand(ms: 61_000) == "60s+")
}
