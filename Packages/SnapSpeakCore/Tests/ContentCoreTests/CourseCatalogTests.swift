import ContentCore
import Testing

@Suite("CourseCatalog")
struct CourseCatalogTests {
    private struct Release: Equatable {
        var courseId: String
        var revision: Int
        var label: String
        var releaseId: String? = nil
    }

    private func uniqued(_ items: [Release]) -> [Release] {
        CourseCatalog.uniquedActiveReleases(
            items,
            id: { $0.courseId },
            revision: { $0.revision },
            releaseId: { $0.releaseId }
        )
    }

    @Test("同一 courseId は revision 最大を残し courseId 昇順")
    func uniquedKeepsHighestRevisionAndSortsById() {
        let items = [
            Release(courseId: "course_b", revision: 1, label: "b1"),
            Release(courseId: "course_a", revision: 2, label: "a-seed"),
            Release(courseId: "course_a", revision: 5, label: "a-downloaded"),
            Release(courseId: "course_a", revision: 4, label: "a-old"),
            Release(courseId: "course_c", revision: 1, label: "c1"),
        ]
        let uniqued = CourseCatalog.uniquedActiveReleases(
            items,
            id: { $0.courseId },
            revision: { $0.revision }
        )
        #expect(uniqued.map(\.courseId) == ["course_a", "course_b", "course_c"])
        #expect(uniqued.map(\.label) == ["a-downloaded", "b1", "c1"])
    }

    @Test("入力順を逆にしても正規化結果は同じ")
    func uniquedIsIndependentOfInputOrder() {
        let forward = [
            Release(courseId: "z", revision: 1, label: "z1"),
            Release(courseId: "a", revision: 3, label: "a3"),
            Release(courseId: "a", revision: 1, label: "a1"),
        ]
        let reversed = Array(forward.reversed())
        let left = CourseCatalog.uniquedActiveReleases(forward, id: { $0.courseId }, revision: { $0.revision })
        let right = CourseCatalog.uniquedActiveReleases(reversed, id: { $0.courseId }, revision: { $0.revision })
        #expect(left == right)
    }

    @Test("同一 courseId・同一 revision は releaseId 非 nil が勝つ")
    func sameRevisionPrefersNonNilReleaseId() {
        let seedFirst = uniqued([
            Release(courseId: "course_a", revision: 2, label: "seed", releaseId: nil),
            Release(courseId: "course_a", revision: 2, label: "downloaded", releaseId: "rel_b"),
        ])
        let downloadedFirst = uniqued([
            Release(courseId: "course_a", revision: 2, label: "downloaded", releaseId: "rel_b"),
            Release(courseId: "course_a", revision: 2, label: "seed", releaseId: nil),
        ])
        #expect(seedFirst.map(\.label) == ["downloaded"])
        #expect(downloadedFirst.map(\.label) == ["downloaded"])
    }

    @Test("同一 courseId・同一 revision の双方非 nil は releaseId 辞書順で大きい方")
    func sameRevisionPrefersLexicographicallyGreaterReleaseId() {
        let smallerFirst = uniqued([
            Release(courseId: "course_a", revision: 3, label: "smaller", releaseId: "rel_a"),
            Release(courseId: "course_a", revision: 3, label: "larger", releaseId: "rel_b"),
        ])
        let largerFirst = uniqued([
            Release(courseId: "course_a", revision: 3, label: "larger", releaseId: "rel_b"),
            Release(courseId: "course_a", revision: 3, label: "smaller", releaseId: "rel_a"),
        ])
        #expect(smallerFirst.map(\.label) == ["larger"])
        #expect(largerFirst.map(\.label) == ["larger"])
    }

    @Test("同一 courseId・同一 revision で双方 nil は先勝ち")
    func sameRevisionBothNilKeepsFirst() {
        let items = [
            Release(courseId: "course_a", revision: 1, label: "first", releaseId: nil),
            Release(courseId: "course_a", revision: 1, label: "second", releaseId: nil),
        ]
        #expect(uniqued(items).map(\.label) == ["first"])
    }

    @Test("同一 revision の tie-break は入力逆順でも結果一致")
    func sameRevisionTieBreakIsIndependentOfInputOrder() {
        let forward = [
            Release(courseId: "course_z", revision: 1, label: "z-seed", releaseId: nil),
            Release(courseId: "course_a", revision: 4, label: "a-small", releaseId: "rel_a"),
            Release(courseId: "course_a", revision: 4, label: "a-large", releaseId: "rel_c"),
            Release(courseId: "course_z", revision: 1, label: "z-dl", releaseId: "rel_z"),
        ]
        let left = uniqued(forward)
        let right = uniqued(Array(forward.reversed()))
        #expect(left == right)
        #expect(left.map(\.label) == ["a-large", "z-dl"])
    }
}
