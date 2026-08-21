import Foundation

public struct ResponseClock: Sendable, Equatable {
    public var t0: Date
    public var tSpeak: Date?
    public var tEnd: Date
    public var maxLatencyMs: Int

    public init(t0: Date, tSpeak: Date? = nil, tEnd: Date, maxLatencyMs: Int = 60_000) {
        self.t0 = t0
        self.tSpeak = tSpeak
        self.tEnd = tEnd
        self.maxLatencyMs = maxLatencyMs
    }

    /// `tEnd − t0`, clipped at `maxLatencyMs`.
    public var latencyMs: Int {
        let raw = Int((tEnd.timeIntervalSince(t0) * 1000.0).rounded())
        return min(max(raw, 0), maxLatencyMs)
    }
}
