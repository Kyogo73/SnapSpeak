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

@Test func streakBandBoundaries() {
    #expect(Quantization.streakBand(days: 1) == "1")
    #expect(Quantization.streakBand(days: 2) == "2-3")
    #expect(Quantization.streakBand(days: 3) == "2-3")
    #expect(Quantization.streakBand(days: 4) == "4-6")
    #expect(Quantization.streakBand(days: 6) == "4-6")
    #expect(Quantization.streakBand(days: 7) == "7-13")
    #expect(Quantization.streakBand(days: 13) == "7-13")
    #expect(Quantization.streakBand(days: 14) == "14-29")
    #expect(Quantization.streakBand(days: 29) == "14-29")
    #expect(Quantization.streakBand(days: 30) == "30+")
    #expect(Quantization.streakBand(days: 100) == "30+")
}
