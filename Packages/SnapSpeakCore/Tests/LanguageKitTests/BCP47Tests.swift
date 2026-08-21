import Foundation
import LanguageKit
import Testing

@Test func normalizesZHHans() throws {
    let language = try BCP47Language("ZH-HANS")
    #expect(language.raw == "zh-Hans")
}

@Test func normalizesEnUS() throws {
    let language = try BCP47Language("en-us")
    #expect(language.raw == "en-US")
}

@Test func japaneseIsIdentity() throws {
    let language = try BCP47Language("ja")
    #expect(language.raw == "ja")
}

@Test func mixedCaseChineseScript() throws {
    let language = try BCP47Language("ZH-hans")
    #expect(language.raw == "zh-Hans")
}

@Test func invalidTagsThrow() {
    #expect(throws: BCP47LanguageError.self) {
        _ = try BCP47Language("")
    }
    #expect(throws: BCP47LanguageError.self) {
        _ = try BCP47Language("en--US")
    }
    #expect(throws: BCP47LanguageError.self) {
        _ = try BCP47Language("-en")
    }
    #expect(throws: BCP47LanguageError.self) {
        _ = try BCP47Language("e")
    }
    #expect(throws: BCP47LanguageError.self) {
        _ = try BCP47Language("en_US")
    }
}

@Test func zhAloneIsNotRejected() throws {
    let language = try BCP47Language("zh")
    #expect(language.raw == "zh")
}

@Test func pairKeyUsesGreaterThan() throws {
    let pair = LanguagePair(
        sourceLanguage: try BCP47Language("ja"),
        targetLanguage: try BCP47Language("en")
    )
    #expect(pair.pairKey == "ja>en")
}

@Test func speechLocaleEnMapsToEnUS() throws {
    let resolver = StaticSpeechLocaleResolver()
    let locale = resolver.speechLocale(for: try BCP47Language("en"), regionPreference: nil)
    #expect(locale?.identifier == "en-US")
    #expect(resolver.speechLocale(for: try BCP47Language("ja"), regionPreference: nil) == nil)
    #expect(resolver.speechLocale(for: try BCP47Language("zh-Hans"), regionPreference: nil) == nil)
}

@Test func appVersionOrdering() throws {
    #expect(try AppVersion("1.0.0") < AppVersion("1.4.0"))
    #expect(try AppVersion("1.4.0") < AppVersion("2.0.0"))
    #expect(try AppVersion("1.0.0") == AppVersion("1.0.0"))
}
