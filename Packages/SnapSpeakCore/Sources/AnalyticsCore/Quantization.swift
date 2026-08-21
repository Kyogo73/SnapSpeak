import Foundation

public enum Quantization: Sendable {
    /// Quantize `scriptMatchRate` to 0.1 steps (half away from zero).
    public static func scoreBand(_ scriptMatchRate: Double) -> Double {
        let clamped = min(max(scriptMatchRate, 0), 1)
        return (clamped * 10.0).rounded() / 10.0
    }

    public static func durationBand(ms: Int) -> String {
        switch ms {
        case ..<5_000: return "0-5s"
        case ..<15_000: return "5-15s"
        case ..<30_000: return "15-30s"
        case ..<60_000: return "30-60s"
        default: return "60s+"
        }
    }
}
