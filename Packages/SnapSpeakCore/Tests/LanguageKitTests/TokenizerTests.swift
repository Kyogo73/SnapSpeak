import Foundation
import LanguageKit
import Testing

@Test func splitsOnPunctuationViaNormalization() throws {
    let tokenizer = WhitespaceTokenizer()
    let tokens = tokenizer.tokenize("Hello, world!", language: try BCP47Language("en"))
    #expect(tokens.map(\.normalized) == ["hello", "world"])
}

@Test func identifiesFillers() throws {
    let tokenizer = WhitespaceTokenizer()
    let language = try BCP47Language("en")
    let tokens = tokenizer.tokenize("um I think uh yes", language: language)
    let lexicon = FillerLexicon()
    let fillers = tokens.filter { lexicon.isFiller($0, language: language) }.map(\.normalized)
    #expect(fillers == ["um", "uh"])
}

@Test func emptyStringYieldsNoTokens() throws {
    let tokenizer = WhitespaceTokenizer()
    #expect(tokenizer.tokenize("", language: try BCP47Language("en")).isEmpty)
}

@Test func multipleSpacesAreCollapsed() throws {
    let tokenizer = WhitespaceTokenizer()
    let tokens = tokenizer.tokenize("hello    there", language: try BCP47Language("en"))
    #expect(tokens.map(\.normalized) == ["hello", "there"])
}

@Test func contractionsBecomeMultipleTokens() throws {
    let tokenizer = WhitespaceTokenizer()
    let tokens = tokenizer.tokenize("don't you think it's ready", language: try BCP47Language("en"))
    #expect(tokens.map(\.normalized) == ["do", "not", "you", "think", "it", "is", "ready"])
}
