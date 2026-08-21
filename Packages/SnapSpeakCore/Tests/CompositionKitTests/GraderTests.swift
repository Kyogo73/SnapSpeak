import Foundation
import CompositionKit
import LanguageKit
import Testing

@Test func contractionVariantPasses() throws {
    let grader = CompositionGrader()
    let language = try BCP47Language("en")
    let grade = grader.grade(
        input: "I'm running late",
        acceptable: ["I am running late"],
        language: language
    )
    #expect(grade == .pass(kind: .normalizedMatch))
}

@Test func fullwidthInputPasses() throws {
    let grader = CompositionGrader()
    let grade = grader.grade(
        input: "Ｈｅｌｌｏ",
        acceptable: ["hello"],
        language: try BCP47Language("en")
    )
    #expect(grade == .pass(kind: .normalizedMatch))
}

@Test func missingArticleFails() throws {
    let grader = CompositionGrader()
    let grade = grader.grade(
        input: "I have apple",
        acceptable: ["I have an apple"],
        language: try BCP47Language("en")
    )
    #expect(grade == .fail)
}

@Test func caseAndPunctuationDifferencesPass() throws {
    let grader = CompositionGrader()
    let grade = grader.grade(
        input: "HELLO, WORLD!",
        acceptable: ["hello world"],
        language: try BCP47Language("en")
    )
    #expect(grade == .pass(kind: .normalizedMatch))
}

@Test func multipleAcceptablePatterns() throws {
    let grader = CompositionGrader()
    let language = try BCP47Language("en")
    #expect(
        grader.grade(
            input: "Can we start in ten minutes?",
            acceptable: [
                "Could we start in ten minutes?",
                "Can we start in ten minutes?",
            ],
            language: language
        ) == .pass(kind: .normalizedMatch)
    )
}

@Test func partialMatchIsNotPass() throws {
    let grader = CompositionGrader()
    let grade = grader.grade(
        input: "Could we start",
        acceptable: ["Could we start in ten minutes?"],
        language: try BCP47Language("en")
    )
    #expect(grade == .fail)
}

@Test func responseClockClipsUpperBound() {
    let t0 = Date(timeIntervalSince1970: 1_000)
    let clock = ResponseClock(
        t0: t0,
        tSpeak: t0.addingTimeInterval(1),
        tEnd: t0.addingTimeInterval(120),
        maxLatencyMs: 60_000
    )
    #expect(clock.latencyMs == 60_000)
}
