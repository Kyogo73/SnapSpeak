import ContentKit
import DriveKit
import DriveModeFeature
import Foundation
import HabitKit
import Testing

@Suite("DrivePlanResolver")
struct DrivePlanResolverTests {
    @Test("due → new の順序を保存し language / 本文を写像する")
    func resolvePreservesOrderAndMapsFields() throws {
        let course = try DriveTestSupport.shadowingCourse(
            lessons: [("lesson_1", ["due_item", "new_item"])]
        )
        let plan = SessionPlan(
            reviews: [DriveTestSupport.due(courseId: "course_a", itemId: "due_item")],
            deferredDueCount: 0,
            newLesson: LessonSummary(
                courseId: "course_a",
                lessonId: "lesson_1",
                mode: "shadowing",
                itemIds: ["new_item"]
            )
        )
        let resolved = DrivePlanResolver.resolve(plan: plan, courses: [DriveTestSupport.stored(course)])
        #expect(resolved.items.map(\.itemId) == ["due_item", "new_item"])
        #expect(resolved.items.map(\.origin) == [.due, .new])
        #expect(resolved.items.map(\.l2Text) == ["Hello due_item", "Hello new_item"])
        #expect(resolved.items.allSatisfy { $0.l1LanguageTag == "ja" && $0.l2LanguageTag == "en" })
        #expect(resolved.skipped == 0)
        #expect(resolved.lookups["course_a|due_item"]?.lessonId == "lesson_1")
        #expect(resolved.lookups["course_a|due_item"]?.courseTitle == "日常英会話")
    }

    @Test("courseId + itemId で解決し、欠損はスキップする")
    func resolveSkipsMissingItems() throws {
        let course = try DriveTestSupport.shadowingCourse(lessons: [("lesson_1", ["item_ok"])])
        let plan = SessionPlan(
            reviews: [
                DriveTestSupport.due(courseId: "course_a", itemId: "item_ok"),
                DriveTestSupport.due(courseId: "course_a", itemId: "item_missing"),
            ],
            deferredDueCount: 0,
            newLesson: LessonSummary(
                courseId: "course_a",
                lessonId: "lesson_1",
                mode: "shadowing",
                itemIds: ["item_ok", "item_gone"]
            )
        )
        let resolved = DrivePlanResolver.resolve(plan: plan, courses: [DriveTestSupport.stored(course)])
        #expect(resolved.items.map(\.itemId) == ["item_ok"])
        #expect(resolved.items.map(\.origin) == [.due])
        #expect(resolved.skipped == 2)
    }

    @Test("due と new の courseId+itemId 重複は due のみ残す")
    func resolveDropsNewDuplicateOfDue() throws {
        let course = try DriveTestSupport.shadowingCourse(
            lessons: [("lesson_1", ["item_ok", "item_new"])]
        )
        let plan = SessionPlan(
            reviews: [DriveTestSupport.due(courseId: "course_a", itemId: "item_ok")],
            deferredDueCount: 0,
            newLesson: LessonSummary(
                courseId: "course_a",
                lessonId: "lesson_1",
                mode: "shadowing",
                itemIds: ["item_ok", "item_new"]
            )
        )
        let resolved = DrivePlanResolver.resolve(plan: plan, courses: [DriveTestSupport.stored(course)])
        #expect(resolved.items.map(\.itemId) == ["item_ok", "item_new"])
        #expect(resolved.items.map(\.origin) == [.due, .new])
    }

    @Test("composition は l1 と acceptable 先頭を写像する")
    func resolveMapsCompositionTexts() throws {
        let course = try DriveTestSupport.compositionCourse(acceptable: ["Hello", "Hi"])
        let plan = SessionPlan(
            reviews: [
                DriveTestSupport.due(courseId: "course_comp", itemId: "item_c", skill: .composition)
            ],
            deferredDueCount: 0,
            newLesson: nil
        )
        let resolved = DrivePlanResolver.resolve(plan: plan, courses: [DriveTestSupport.stored(course)])
        #expect(resolved.items.count == 1)
        #expect(resolved.items[0].l1Text == "こんにちは")
        #expect(resolved.items[0].l2Text == "Hello")
        #expect(resolved.items[0].skill == .composition)
    }

    @Test("別コースの同名 itemId を混同しない")
    func resolveKeepsSameItemIdOnDifferentCourses() throws {
        let courseA = try DriveTestSupport.shadowingCourse(id: "course_a", lessons: [("l", ["shared"])])
        let courseB = try DriveTestSupport.shadowingCourse(id: "course_b", lessons: [("l", ["shared"])])
        let plan = SessionPlan(
            reviews: [
                DriveTestSupport.due(courseId: "course_a", itemId: "shared"),
                DriveTestSupport.due(courseId: "course_b", itemId: "shared", at: 2),
            ],
            deferredDueCount: 0,
            newLesson: nil
        )
        let resolved = DrivePlanResolver.resolve(
            plan: plan,
            courses: [DriveTestSupport.stored(courseA), DriveTestSupport.stored(courseB)]
        )
        #expect(resolved.items.map(\.courseId) == ["course_a", "course_b"])
        #expect(resolved.skipped == 0)
    }

    @Test("プラン空の repeatFillItems はカタログ順で origin=repeatFill")
    func repeatFillUsesCatalogOrder() throws {
        let courseB = try DriveTestSupport.shadowingCourse(id: "course_b", lessons: [("lb", ["ib"])])
        let courseA = try DriveTestSupport.shadowingCourse(id: "course_a", lessons: [("la", ["ia1", "ia2"])])
        let filled = DrivePlanResolver.repeatFillItems(
            courses: [DriveTestSupport.stored(courseB), DriveTestSupport.stored(courseA)],
            limit: 10
        )
        #expect(filled.items.map(\.itemId) == ["ia1", "ia2", "ib"])
        #expect(filled.items.map(\.courseId) == ["course_a", "course_a", "course_b"])
        #expect(filled.items.allSatisfy { $0.origin == .repeatFill })
    }

    @Test("repeatFillItems は limit で切る")
    func repeatFillRespectsLimit() throws {
        let course = try DriveTestSupport.shadowingCourse(
            lessons: [("lesson_1", ["a", "b", "c"])]
        )
        let filled = DrivePlanResolver.repeatFillItems(
            courses: [DriveTestSupport.stored(course)],
            limit: 2
        )
        #expect(filled.items.map(\.itemId) == ["a", "b"])
    }
}
