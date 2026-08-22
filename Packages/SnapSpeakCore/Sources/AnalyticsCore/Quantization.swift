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

    /// ストリーク日数の帯（生値を送らない）。"1" | "2-3" | "4-6" | "7-13" | "14-29" | "30+"
    public static func streakBand(days: Int) -> String {
        switch days {
        case ...1: return "1"
        case 2...3: return "2-3"
        case 4...6: return "4-6"
        case 7...13: return "7-13"
        case 14...29: return "14-29"
        default: return "30+"
        }
    }
}
