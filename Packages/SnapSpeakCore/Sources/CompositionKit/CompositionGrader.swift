import Foundation
import LanguageKit

public struct CompositionGrader: Sendable {
    private let normalizer: EnglishNormalizer

    public init(normalizer: EnglishNormalizer = EnglishNormalizer()) {
        self.normalizer = normalizer
    }

    public func grade(input: String, acceptable: [String], language: BCP47Language) -> CompositionGrade {
        _ = language
        let hyp = normalizer.normalize(input)
        let refs = acceptable.map { normalizer.normalize($0) }
        if refs.contains(hyp) {
            return .pass(kind: .normalizedMatch)
        }
        return .fail
    }
}
