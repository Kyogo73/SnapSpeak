import Foundation

/// Phase 1 tokenizer: normalize the whole string, then split on whitespace.
public struct WhitespaceTokenizer: Tokenizer {
    private let normalizer: EnglishNormalizer

    public init(normalizer: EnglishNormalizer = EnglishNormalizer()) {
        self.normalizer = normalizer
    }

    public func tokenize(_ text: String, language: BCP47Language) -> [Token] {
        _ = language
        let normalized = normalizer.normalize(text)
        if normalized.isEmpty { return [] }
        return normalized.split(whereSeparator: \.isWhitespace).map { piece in
            let value = String(piece)
            return Token(surface: value, normalized: value)
        }
    }
}
