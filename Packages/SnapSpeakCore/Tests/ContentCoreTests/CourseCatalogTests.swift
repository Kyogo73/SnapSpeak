import ContentCore
import Testing

@Suite("CourseCatalog")
struct CourseCatalogTests {
    private struct Release: Equatable {
        var courseId: String
        var revision: Int
        var label: String
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
}
