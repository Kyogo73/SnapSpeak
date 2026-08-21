import Foundation

public enum WPMCalculator: Sendable {
    public static func wordsPerMinute(tokenCount: Int, utteranceSeconds: Double) -> Double {
        guard utteranceSeconds > 0 else { return 0 }
        return Double(tokenCount) / (utteranceSeconds / 60.0)
    }
}
