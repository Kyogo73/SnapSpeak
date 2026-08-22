import Analytics
import ContentCore
import ContentKit
import Foundation
import HabitKit
import LanguageKit
import Persistence
import ReviewFeature
import SRSKit
import Testing

@Suite("ReviewFeature mappings")
struct ReviewFeatureMappingTests {
    @Test("lessonSummaries がカタログ順")
    func lessonSummariesPreserveCatalogOrder() throws {
        let courseA = try makeCourse(id: "course_a", lessons: [
            ("l1", ["i1"]),
            ("l2", ["i2"]),
        ])
        let courseB = try makeCourse(id: "course_b", lessons: [
            ("l3", ["i3"]),
        ])
        let summaries = TodayPlanService.lessonSummaries(from: [
            stored(courseA),
            stored(courseB),
        ])
        #expect(summaries.map(\.lessonId) == ["l1", "l2", "l3"])
        #expect(summaries.map(\.courseId) == ["course_a", "course_a", "course_b"])
    }

    @Test("同一 courseId の seed/downloaded は revision 最大だけ残す")
    func lessonSummariesUniquesByCourseId() throws {
        let seed = try makeCourse(id: "course_a", lessons: [("old", ["i1"])])
        let downloaded = try makeCourse(id: "course_a", lessons: [("new", ["i2"])])
        let other = try makeCourse(id: "course_b", lessons: [("b1", ["i3"])])
        let summaries = TodayPlanService.lessonSummaries(from: [
            stored(downloaded, revision: 5),
            stored(seed, revision: 1),
            stored(other, revision: 0),
        ])
        #expect(summaries.map(\.courseId) == ["course_a", "course_b"])
        #expect(summaries.map(\.lessonId) == ["new", "b1"])
    }

    @Test("新規レッスン区切りは先頭または due から new への境界")
    func newLessonIntroBoundaries() {
        let due = ReviewEntry(
            id: "d",
            courseId: "c",
            lessonId: "l",
            itemId: "i1",
            mode: .shadowing,
            origin: .due(cardKey: "k")
        )
        let firstNew = ReviewEntry(
            id: "n1",
            courseId: "c",
            lessonId: "l",
            itemId: "i2",
            mode: .shadowing,
            origin: .newLesson
        )
        let secondNew = ReviewEntry(
            id: "n2",
            courseId: "c",
            lessonId: "l",
            itemId: "i3",
            mode: .shadowing,
            origin: .newLesson
        )
        #expect(ReviewSessionViewModel.shouldInsertNewLessonIntro(entries: [firstNew, secondNew], at: 0))
        #expect(ReviewSessionViewModel.shouldInsertNewLessonIntro(entries: [due, firstNew, secondNew], at: 1))
        #expect(ReviewSessionViewModel.shouldInsertNewLessonIntro(entries: [due, firstNew, secondNew], at: 2) == false)
        #expect(ReviewSessionViewModel.shouldInsertNewLessonIntro(entries: [due], at: 0) == false)
    }

    @Test("dueCard(from:) の写像")
    func dueCardMapping() {
        let due = Date(timeIntervalSince1970: 1_700_000_000)
        let gate = Date(timeIntervalSince1970: 1_700_000_600)
        let dto = SRSCardDTO(
            cardKey: "ja>en:course_a:item_1:composition",
            sourceLanguage: "ja",
            targetLanguage: "en",
            courseId: "course_a",
            itemId: "item_1",
            skill: Skill.composition.rawValue,
            contentRevision: 1,
            inheritSRS: true,
            easiness: 2.5,
            intervalDays: 1,
            repetitions: 1,
            dueAt: due,
            relearnGateAt: gate,
            lastReviewedAt: due,
            lastQuality: 4,
            foldedThroughRevision: nil
        )
        let card = TodayPlanService.dueCard(from: dto)
        #expect(card?.cardKey == dto.cardKey)
        #expect(card?.courseId == "course_a")
        #expect(card?.itemId == "item_1")
        #expect(card?.skill == .composition)
        #expect(card?.dueAt == due)
        #expect(card?.relearnGateAt == gate)

        var invalid = dto
        invalid.skill = "unknown"
        #expect(TodayPlanService.dueCard(from: invalid) == nil)
    }

    @Test("resolveEntries は欠損をスキップして件数を返す")
    func resolveEntriesSkipsMissing() throws {
        let course = try makeCourse(id: "course_a", lessons: [
            ("lesson_1", ["item_ok"]),
        ])
        let due = DueCard(
            cardKey: "k1",
            courseId: "course_a",
            itemId: "item_ok",
            skill: .shadowing,
            dueAt: Date(timeIntervalSince1970: 1),
            relearnGateAt: nil
        )
        let missing = DueCard(
            cardKey: "k2",
            courseId: "course_a",
            itemId: "item_missing",
            skill: .shadowing,
            dueAt: Date(timeIntervalSince1970: 2),
            relearnGateAt: nil
        )
        let newLesson = LessonSummary(
            courseId: "course_a",
            lessonId: "lesson_1",
            mode: "shadowing",
            itemIds: ["item_ok", "item_gone"]
        )
        let plan = SessionPlan(reviews: [due, missing], deferredDueCount: 0, newLesson: newLesson)
        let resolved = ReviewSessionViewModel.resolveEntries(plan: plan, courses: [stored(course)])
        #expect(resolved.entries.map(\.itemId) == ["item_ok"])
        #expect(resolved.entries.map(\.origin) == [.due(cardKey: "k1")])
        #expect(resolved.skipped == 2)
    }

    @Test("due と new の courseId+itemId 重複は due のみ残す")
    func resolveEntriesDropsNewDuplicateOfDue() throws {
        let course = try makeCourse(id: "course_a", lessons: [
            ("lesson_1", ["item_ok", "item_new"]),
        ])
        let due = DueCard(
            cardKey: "k1",
            courseId: "course_a",
            itemId: "item_ok",
            skill: .shadowing,
            dueAt: Date(timeIntervalSince1970: 1),
            relearnGateAt: nil
        )
        let newLesson = LessonSummary(
            courseId: "course_a",
            lessonId: "lesson_1",
            mode: "shadowing",
            itemIds: ["item_ok", "item_new"]
        )
        let plan = SessionPlan(reviews: [due], deferredDueCount: 0, newLesson: newLesson)
        let resolved = ReviewSessionViewModel.resolveEntries(plan: plan, courses: [stored(course)])
        #expect(resolved.entries.map(\.itemId) == ["item_ok", "item_new"])
        #expect(resolved.entries.map(\.origin) == [.due(cardKey: "k1"), .newLesson])
        #expect(resolved.skipped == 0)
    }

    @Test("intro 二重タップは先頭 Item を飛ばさない")
    @MainActor
    func introDoubleTapDoesNotSkipFirstItem() {
        let first = ReviewEntry(
            id: "n1",
            courseId: "c",
            lessonId: "l",
            itemId: "i1",
            mode: .shadowing,
            origin: .newLesson
        )
        let second = ReviewEntry(
            id: "n2",
            courseId: "c",
            lessonId: "l",
            itemId: "i2",
            mode: .shadowing,
            origin: .newLesson
        )
        let vm = ReviewSessionViewModel(
            plan: SessionPlan(reviews: [], deferredDueCount: 0, newLesson: nil),
            courseStore: emptyStore(),
            analytics: NoopAnalytics()
        )
        vm.startResolved(entries: [first, second])
        #expect(vm.phase == .newLessonIntro)
        vm.continueNewLesson()
        vm.continueNewLesson()
        #expect(vm.phase == .running(index: 0, total: 2))
        #expect(vm.current?.itemId == "i1")
        #expect(vm.completedCount == 0)
        vm.advance()
        #expect(vm.current?.itemId == "i2")
        #expect(vm.completedCount == 1)
    }

    @Test("skip は completedCount を増やさない")
    @MainActor
    func skipDoesNotIncrementCompletedCount() {
        let first = ReviewEntry(
            id: "d1",
            courseId: "c",
            lessonId: "l",
            itemId: "i1",
            mode: .shadowing,
            origin: .due(cardKey: "k")
        )
        let second = ReviewEntry(
            id: "d2",
            courseId: "c",
            lessonId: "l",
            itemId: "i2",
            mode: .shadowing,
            origin: .due(cardKey: "k2")
        )
        let vm = ReviewSessionViewModel(
            plan: SessionPlan(reviews: [], deferredDueCount: 0, newLesson: nil),
            courseStore: emptyStore(),
            analytics: NoopAnalytics()
        )
        vm.startResolved(entries: [first, second])
        vm.skip()
        #expect(vm.completedCount == 0)
        #expect(vm.skippedByUserCount == 1)
        #expect(vm.skippedMissingCount == 0)
        #expect(vm.current?.itemId == "i2")
    }

    @Test("ReviewEntry.id は due/new 判別子込みで一意")
    func reviewEntryIdsIncludeOriginAndStayUnique() throws {
        let course = try makeCourse(id: "course_a", lessons: [
            ("lesson_1", ["item_due", "item_new"]),
        ])
        let due = DueCard(
            cardKey: "k1",
            courseId: "course_a",
            itemId: "item_due",
            skill: .shadowing,
            dueAt: Date(timeIntervalSince1970: 1),
            relearnGateAt: nil
        )
        let newLesson = LessonSummary(
            courseId: "course_a",
            lessonId: "lesson_1",
            mode: "shadowing",
            itemIds: ["item_new"]
        )
        let resolved = ReviewSessionViewModel.resolveEntries(
            plan: SessionPlan(reviews: [due], deferredDueCount: 0, newLesson: newLesson),
            courses: [stored(course)]
        )
        #expect(resolved.entries.map(\.id) == [
            "course_a/item_due/due",
            "course_a/item_new/new",
        ])
        #expect(Set(resolved.entries.map(\.id)).count == 2)
    }

    @Test("別コースの同名 itemId を混同しない")
    func resolveEntriesKeepsSameItemIdOnDifferentCourses() throws {
        let courseA = try makeCourse(id: "course_a", lessons: [("l", ["shared"])])
        let courseB = try makeCourse(id: "course_b", lessons: [("l", ["shared"])])
        let dueA = DueCard(
            cardKey: "ka",
            courseId: "course_a",
            itemId: "shared",
            skill: .shadowing,
            dueAt: Date(timeIntervalSince1970: 1),
            relearnGateAt: nil
        )
        let dueB = DueCard(
            cardKey: "kb",
            courseId: "course_b",
            itemId: "shared",
            skill: .shadowing,
            dueAt: Date(timeIntervalSince1970: 2),
            relearnGateAt: nil
        )
        let resolved = ReviewSessionViewModel.resolveEntries(
            plan: SessionPlan(reviews: [dueA, dueB], deferredDueCount: 0, newLesson: nil),
            courses: [stored(courseA), stored(courseB)]
        )
        #expect(resolved.entries.map(\.courseId) == ["course_a", "course_b"])
        #expect(resolved.entries.map(\.itemId) == ["shared", "shared"])
        #expect(Set(resolved.entries.map(\.id)).count == 2)
        #expect(resolved.skipped == 0)
    }

    @Test("欠損スキップとユーザースキップは独立に数える")
    @MainActor
    func missingAndUserSkipsAreIndependent() {
        let first = ReviewEntry(
            id: "d1",
            courseId: "c",
            lessonId: "l",
            itemId: "i1",
            mode: .shadowing,
            origin: .due(cardKey: "k")
        )
        let second = ReviewEntry(
            id: "d2",
            courseId: "c",
            lessonId: "l",
            itemId: "i2",
            mode: .shadowing,
            origin: .due(cardKey: "k2")
        )
        let vm = ReviewSessionViewModel(
            plan: SessionPlan(reviews: [], deferredDueCount: 0, newLesson: nil),
            courseStore: emptyStore(),
            analytics: NoopAnalytics()
        )
        vm.startResolved(entries: [first, second], skipped: 3)
        #expect(vm.skippedMissingCount == 3)
        #expect(vm.skippedByUserCount == 0)
        vm.skip()
        #expect(vm.skippedMissingCount == 3)
        #expect(vm.skippedByUserCount == 1)
        #expect(vm.completedCount == 0)
        vm.advance()
        #expect(vm.skippedMissingCount == 3)
        #expect(vm.skippedByUserCount == 1)
        #expect(vm.completedCount == 1)
    }

    private func emptyStore() -> CourseStore {
        CourseStore(
            seed: SeedInstaller(bundle: .main),
            downloadsRoot: FileManager.default.temporaryDirectory
                .appendingPathComponent("review-tests-\(UUID().uuidString)", isDirectory: true)
        )
    }

    private func stored(_ course: Course, revision: Int = 0) -> StoredCourse {
        StoredCourse(
            course: course,
            origin: .seed,
            directory: URL(fileURLWithPath: "/tmp"),
            revision: revision,
            releaseId: nil
        )
    }

    private func makeCourse(id: String, lessons: [(String, [String])]) throws -> Course {
        let pair = LanguagePair(
            sourceLanguage: try BCP47Language("ja"),
            targetLanguage: try BCP47Language("en")
        )
        let unitLessons: [LessonV1] = try lessons.map { lessonId, itemIds in
            let items: [ItemV1] = try itemIds.map { itemId in
                try ItemV1(
                    id: itemId,
                    kind: .shadowing,
                    audio: AudioRef(
                        relativePath: "audio/\(itemId).m4a",
                        durationMs: 1_000,
                        checksumSha256: String(repeating: "ab", count: 32)
                    ),
                    passage: PassageV1(
                        text: "Hi",
                        captionSegments: [CaptionSegment(startMs: 0, endMs: 400, text: "Hi")]
                    )
                )
            }
            return LessonV1(id: lessonId, mode: .shadowing, items: items)
        }
        return CourseV1(
            schemaVersion: 1,
            id: id,
            languagePair: pair,
            title: ["ja": id],
            units: [UnitV1(id: "unit_1", title: ["ja": "u"], lessons: unitLessons)]
        )
    }
}

private struct NoopAnalytics: AnalyticsClient {
    func track(_ event: AnalyticsEvent) {}
}
