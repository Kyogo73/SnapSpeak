import Foundation

/// First-class content language pair. `pairKey` uses `>` so it never collides with `:`-delimited card keys.
public struct LanguagePair: Hashable, Sendable, Codable {
    public var sourceLanguage: BCP47Language
    public var targetLanguage: BCP47Language

    public init(sourceLanguage: BCP47Language, targetLanguage: BCP47Language) {
        self.sourceLanguage = sourceLanguage
        self.targetLanguage = targetLanguage
    }

    public var pairKey: String {
        "\(sourceLanguage.raw)>\(targetLanguage.raw)"
    }
}
