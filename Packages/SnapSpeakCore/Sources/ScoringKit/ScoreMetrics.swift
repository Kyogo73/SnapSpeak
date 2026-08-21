import Foundation

public enum ScoreMetrics: Sendable {
    public static func scriptMatchRate(equalCount: Int, referenceCount n: Int) -> Double {
        Double(equalCount) / Double(max(n, 1))
    }

    public static func precision(equalCount: Int, hypothesisCount m: Int) -> Double {
        Double(equalCount) / Double(max(m, 1))
    }

    public static func recall(equalCount: Int, referenceCount n: Int) -> Double {
        Double(equalCount) / Double(max(n, 1))
    }
}
