import Foundation

/// Standard Levenshtein DP (match 0 / substitute 1 / delete 1 / insert 1) with deterministic backtrace.
public enum Aligner: Sendable {
    public static func align(reference: [String], hypothesis: [String]) -> [AlignmentOp] {
        let n = reference.count
        let m = hypothesis.count
        var dp = Array(repeating: Array(repeating: 0, count: m + 1), count: n + 1)
        for i in 0...n { dp[i][0] = i }
        for j in 0...m { dp[0][j] = j }

        if n > 0 && m > 0 {
            for i in 1...n {
                for j in 1...m {
                    let cost = reference[i - 1] == hypothesis[j - 1] ? 0 : 1
                    dp[i][j] = min(
                        dp[i - 1][j - 1] + cost,
                        dp[i - 1][j] + 1,
                        dp[i][j - 1] + 1
                    )
                }
            }
        }

        var ops: [AlignmentOp] = []
        var i = n
        var j = m
        while i > 0 || j > 0 {
            if i > 0, j > 0 {
                let cost = reference[i - 1] == hypothesis[j - 1] ? 0 : 1
                if dp[i][j] == dp[i - 1][j - 1] + cost {
                    if cost == 0 {
                        ops.append(.equal(ref: i - 1, hyp: j - 1))
                    } else {
                        ops.append(.substitution(ref: i - 1, hyp: j - 1))
                    }
                    i -= 1
                    j -= 1
                    continue
                }
            }
            if i > 0, dp[i][j] == dp[i - 1][j] + 1 {
                ops.append(.deletion(ref: i - 1))
                i -= 1
                continue
            }
            ops.append(.insertion(hyp: j - 1))
            j -= 1
        }
        return ops.reversed()
    }
}
