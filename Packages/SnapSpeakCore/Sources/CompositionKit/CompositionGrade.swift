import Foundation

public enum CompositionPassKind: String, Sendable, Equatable {
    case normalizedMatch
    /// Reserved for Phase 3 LLM semantic pass. Not produced in Phase 1.
    case semantic
}

public enum CompositionGrade: Sendable, Equatable {
    case pass(kind: CompositionPassKind)
    case fail
    /// Speech 拒否・ASR 不可・認識エラー。不一致ではない。
    case unscored

    /// `.fail` の ReviewEvent は追記しない。Attempt は別途追記する。
    public var shouldAppendReviewEvent: Bool {
        switch self {
        case .pass, .fail:
            return true
        case .unscored:
            return false
        }
    }
}
