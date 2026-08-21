import Foundation
import ScoringKit
import Testing

@Test func completeMatch() {
    let ops = Aligner.align(reference: ["a", "b", "c"], hypothesis: ["a", "b", "c"])
    #expect(ops == [
        .equal(ref: 0, hyp: 0),
        .equal(ref: 1, hyp: 1),
        .equal(ref: 2, hyp: 2),
    ])
}

@Test func leadingMiddleTrailingDeletions() {
    let leading = Aligner.align(reference: ["a", "b", "c"], hypothesis: ["b", "c"])
    #expect(leading == [
        .deletion(ref: 0),
        .equal(ref: 1, hyp: 0),
        .equal(ref: 2, hyp: 1),
    ])

    let middle = Aligner.align(reference: ["a", "b", "c"], hypothesis: ["a", "c"])
    #expect(middle == [
        .equal(ref: 0, hyp: 0),
        .deletion(ref: 1),
        .equal(ref: 2, hyp: 1),
    ])

    let trailing = Aligner.align(reference: ["a", "b", "c"], hypothesis: ["a", "b"])
    #expect(trailing == [
        .equal(ref: 0, hyp: 0),
        .equal(ref: 1, hyp: 1),
        .deletion(ref: 2),
    ])
}

@Test func substitutionAndInsertion() {
    let sub = Aligner.align(reference: ["cat"], hypothesis: ["hat"])
    #expect(sub == [.substitution(ref: 0, hyp: 0)])

    let ins = Aligner.align(reference: ["a", "b"], hypothesis: ["a", "x", "b"])
    #expect(ins == [
        .equal(ref: 0, hyp: 0),
        .insertion(hyp: 1),
        .equal(ref: 1, hyp: 2),
    ])
}

@Test func emptyHypothesisIsAllDeletions() {
    let ops = Aligner.align(reference: ["a", "b"], hypothesis: [])
    #expect(ops == [.deletion(ref: 0), .deletion(ref: 1)])
}

@Test func emptyReferenceIsAllInsertions() {
    let ops = Aligner.align(reference: [], hypothesis: ["a"])
    #expect(ops == [.insertion(hyp: 0)])
}

@Test func emptyBothIsEmptyOps() {
    #expect(Aligner.align(reference: [], hypothesis: []).isEmpty)
}

@Test func backtraceIsDeterministic() {
    let first = Aligner.align(reference: ["a", "b"], hypothesis: ["x", "b"])
    let second = Aligner.align(reference: ["a", "b"], hypothesis: ["x", "b"])
    #expect(first == second)
}
