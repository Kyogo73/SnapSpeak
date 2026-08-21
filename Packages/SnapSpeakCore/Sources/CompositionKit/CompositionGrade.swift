import Foundation

public enum CompositionPassKind: String, Sendable, Equatable {
    case normalizedMatch
    /// Reserved for Phase 3 LLM semantic pass. Not produced in Phase 1.
    case semantic
}

public enum CompositionGrade: Sendable, Equatable {
    case pass(kind: CompositionPassKind)
    case fail
}
