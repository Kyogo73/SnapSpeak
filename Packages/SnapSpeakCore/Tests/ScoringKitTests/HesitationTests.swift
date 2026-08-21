import Foundation
import LanguageKit
import ScoringKit
import Testing

@Test func repeatedTokenInsertionsCountAsHesitation() throws {
    let ops = Aligner.align(
        reference: ["i", "think"],
        hypothesis: ["i", "i", "think"]
    )
    let report = HesitationDetector.detect(
        ops: ops,
        hypothesis: ["i", "i", "think"],
        language: try BCP47Language("en")
    )
    #expect(report.hesitations == 1)
    #expect(report.substitutions == 0)
}

@Test func fillerUmCountsAsHesitation() throws {
    let ops = Aligner.align(
        reference: ["i", "think"],
        hypothesis: ["i", "um", "think"]
    )
    let report = HesitationDetector.detect(
        ops: ops,
        hypothesis: ["i", "um", "think"],
        language: try BCP47Language("en")
    )
    #expect(report.hesitations == 1)
}

@Test func substitutionIsNotHesitation() throws {
    let ops = Aligner.align(reference: ["cat"], hypothesis: ["hat"])
    let report = HesitationDetector.detect(
        ops: ops,
        hypothesis: ["hat"],
        language: try BCP47Language("en")
    )
    #expect(report.hesitations == 0)
    #expect(report.substitutions == 1)
}

@Test func consecutiveDeletionsFormOmissionSpan() throws {
    let ops = Aligner.align(
        reference: ["a", "b", "c", "d"],
        hypothesis: ["a", "d"]
    )
    let report = HesitationDetector.detect(
        ops: ops,
        hypothesis: ["a", "d"],
        language: try BCP47Language("en")
    )
    #expect(report.omissions == [AlignedSpan(startRefIndex: 1, endRefIndex: 3)])
}
