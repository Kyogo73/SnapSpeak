import Foundation

/// L2-locale filler words counted as hesitations, not as reference tokens.
public struct FillerLexicon: Sendable {
    public static let english: Set<String> = [
        "uh", "um", "er", "ah", "hmm", "mm", "mmm", "uhh", "umm", "eh",
    ]

    public init() {}

    public func isFiller(_ token: String, language: BCP47Language) -> Bool {
        let key = token.lowercased()
        if language.languageSubtag == "en" {
            return Self.english.contains(key)
        }
        return Self.english.contains(key)
    }

    public func isFiller(_ token: Token, language: BCP47Language) -> Bool {
        isFiller(token.normalized, language: language)
    }
}
