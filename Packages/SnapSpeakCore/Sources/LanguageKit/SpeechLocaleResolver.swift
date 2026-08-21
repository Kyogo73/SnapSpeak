import Foundation

public protocol SpeechLocaleResolver: Sendable {
    func speechLocale(for targetLanguage: BCP47Language, regionPreference: String?) -> Locale?
}

/// Phase 1 resolver: only `en` (any region) maps to `en-US`. Unlisted languages return nil (ASR off).
public struct StaticSpeechLocaleResolver: SpeechLocaleResolver {
    public init() {}

    public func speechLocale(for targetLanguage: BCP47Language, regionPreference: String?) -> Locale? {
        _ = regionPreference
        guard targetLanguage.languageSubtag == "en" else { return nil }
        return Locale(identifier: "en-US")
    }
}
