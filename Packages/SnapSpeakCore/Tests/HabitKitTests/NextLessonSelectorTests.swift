import Foundation
import HabitKit
import Testing

@Suite("NextLessonSelector")
struct NextLessonSelectorTests {
    private func lesson(
        course: String,
        id: String,
        items: [String],
        mode: String = "shadowing"
    ) -> LessonSummary {
        LessonSummary(courseId: course, lessonId: id, mode: mode, itemIds: items)
    }

    @Test("未着手コース → 先頭レッスン")
    func untouchedCourseReturnsFirstLesson() {
        let lessons = [
            lesson(course: "a", id: "l1", items: ["i1", "i2"]),
            lesson(course: "a", id: "l2", items: ["i3"]),
        ]
        let next = NextLessonSelector.next(lessons: lessons, attempted: [])
        #expect(next?.lessonId == "l1")
    }

    @Test("一部 Item のみ試行済み → 同レッスンが返る")
    func partialLessonRemainsCurrent() {
        let lessons = [
            lesson(course: "a", id: "l1", items: ["i1", "i2"]),
            lesson(course: "a", id: "l2", items: ["i3"]),
        ]
        let attempted: Set<ItemRef> = [ItemRef(courseId: "a", itemId: "i1")]
        let next = NextLessonSelector.next(lessons: lessons, attempted: attempted)
        #expect(next?.lessonId == "l1")
    }

    @Test("全 Item 試行済み → 次レッスン")
    func completedLessonAdvances() {
        let lessons = [
            lesson(course: "a", id: "l1", items: ["i1", "i2"]),
            lesson(course: "a", id: "l2", items: ["i3"]),
        ]
        let attempted: Set<ItemRef> = [
            ItemRef(courseId: "a", itemId: "i1"),
            ItemRef(courseId: "a", itemId: "i2"),
        ]
        let next = NextLessonSelector.next(lessons: lessons, attempted: attempted)
        #expect(next?.lessonId == "l2")
    }

    @Test("全コース完了 → nil")
    func allCompleteReturnsNil() {
        let lessons = [
            lesson(course: "a", id: "l1", items: ["i1"]),
            lesson(course: "b", id: "l2", items: ["i2"]),
        ]
        let attempted: Set<ItemRef> = [
            ItemRef(courseId: "a", itemId: "i1"),
            ItemRef(courseId: "b", itemId: "i2"),
        ]
        #expect(NextLessonSelector.next(lessons: lessons, attempted: attempted) == nil)
    }

    @Test("itemIds 空レッスンをスキップ")
    func emptyItemLessonIsSkipped() {
        let lessons = [
            lesson(course: "a", id: "empty", items: []),
            lesson(course: "a", id: "next", items: ["i1"]),
        ]
        let next = NextLessonSelector.next(lessons: lessons, attempted: [])
        #expect(next?.lessonId == "next")
    }

    @Test("複数コースでカタログ順を維持")
    func catalogOrderAcrossCourses() {
        let lessons = [
            lesson(course: "a", id: "a1", items: ["a_i1"]),
            lesson(course: "a", id: "a2", items: ["a_i2"]),
            lesson(course: "b", id: "b1", items: ["b_i1"]),
        ]
        let attempted: Set<ItemRef> = [
            ItemRef(courseId: "a", itemId: "a_i1"),
            ItemRef(courseId: "a", itemId: "a_i2"),
        ]
        let next = NextLessonSelector.next(lessons: lessons, attempted: attempted)
        #expect(next?.courseId == "b")
        #expect(next?.lessonId == "b1")
    }
}
