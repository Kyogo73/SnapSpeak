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
        #expect(resolved.entries.map(\.itemId) == ["item_ok", "item_ok"])
        #expect(resolved.entries.map(\.origin) == [.due(cardKey: "k1"), .newLesson])
        #expect(resolved.skipped == 2)
    }

    private func stored(_ course: Course) -> StoredCourse {
        StoredCourse(
            course: course,
            origin: .seed,
            directory: URL(fileURLWithPath: "/tmp"),
            revision: 0,
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
