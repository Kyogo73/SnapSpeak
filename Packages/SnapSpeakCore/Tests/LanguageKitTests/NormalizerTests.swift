import Foundation
import LanguageKit
import Testing

@Test func nfkcFullwidthToHalfwidth() {
    let normalizer = EnglishNormalizer()
    #expect(normalizer.normalize("Ｈｅｌｌｏ") == "hello")
}

@Test func smartQuotesBecomeAsciiThenExpand() {
    let normalizer = EnglishNormalizer()
    #expect(normalizer.normalize("Don’t you think it’s ready?") == "do not you think it is ready")
}

@Test func contractionsDontAndIts() {
    let normalizer = EnglishNormalizer()
    #expect(normalizer.normalize("Don't you think it's...") == "do not you think it is")
}

@Test func cantBecomesCanNot() {
    let normalizer = EnglishNormalizer()
    #expect(normalizer.normalize("can't") == "can not")
    #expect(normalizer.normalize("Can't") == "can not")
}

@Test func apostropheSurvivesUntilContractionExpansion() {
    let normalizer = EnglishNormalizer()
    #expect(normalizer.normalize("it's") == "it is")
    #expect(normalizer.normalize("I'm") == "i am")
}

@Test func whitespaceIsCollapsedAndTrimmed() {
    let normalizer = EnglishNormalizer()
    #expect(normalizer.normalize("  Hello,   world!  ") == "hello world")
}

@Test func punctuationIsRemoved() {
    let normalizer = EnglishNormalizer()
    #expect(normalizer.normalize("Hello, world!") == "hello world")
}
