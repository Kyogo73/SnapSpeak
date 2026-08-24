import ScoringKit
@testable import ShadowingFeature
import Testing

@Suite("ResultView breakdown")
struct ResultBreakdownTests {
    @Test("単一区間は end-start の語数")
    func singleSpanWordCount() {
        let omissions = [AlignedSpan(startRefIndex: 2, endRefIndex: 5)]
        #expect(ResultView.omittedWordCount(omissions) == 3)
    }

    @Test("複数区間は各区間語数の合計")
    func multipleSpansSumWordCount() {
        let omissions = [
            AlignedSpan(startRefIndex: 0, endRefIndex: 2),
            AlignedSpan(startRefIndex: 4, endRefIndex: 7),
        ]
        #expect(ResultView.omittedWordCount(omissions) == 5)
    }

    @Test("空配列は 0 語")
    func emptyOmissionsAreZero() {
        #expect(ResultView.omittedWordCount([]) == 0)
    }

    @Test("逆転・ゼロ長区間は 0 にクリップ")
    func reversedAndZeroLengthSpansClipToZero() {
        let omissions = [
            AlignedSpan(startRefIndex: 5, endRefIndex: 2),
            AlignedSpan(startRefIndex: 3, endRefIndex: 3),
        ]
        #expect(ResultView.omittedWordCount(omissions) == 0)
    }
}
