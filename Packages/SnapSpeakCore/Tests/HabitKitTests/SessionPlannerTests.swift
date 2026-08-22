import Foundation
import HabitKit
import SRSKit
import Testing

@Suite("SessionPlanner")
struct SessionPlannerTests {
    private let now = Date(timeIntervalSince1970: 1_777_000_000)

    private func card(
        itemId: String,
        skill: Skill,
        dueOffset: TimeInterval,
        gateOffset: TimeInterval? = nil,
        courseId: String = "course_a"
    ) -> DueCard {
        DueCard(
            cardKey: "ja>en:\(courseId):\(itemId):\(skill.rawValue)",
            courseId: courseId,
            itemId: itemId,
            skill: skill,
            dueAt: now.addingTimeInterval(dueOffset),
            relearnGateAt: gateOffset.map { now.addingTimeInterval($0) }
        )
    }

    private var sampleLesson: LessonSummary {
        LessonSummary(courseId: "course_a", lessonId: "lesson_new", mode: "shadowing", itemIds: ["n1"])
    }

    @Test("空 due + 新規なし → isEmpty")
    func emptyPlan() {
        let plan = SessionPlanner.plan(dueCards: [], newLesson: nil, now: now)
        #expect(plan.isEmpty)
        #expect(plan.reviews.isEmpty)
        #expect(plan.deferredDueCount == 0)
        #expect(plan.newLesson == nil)
    }

    @Test("dueAt == now ちょうどは含む")
    func dueAtEqualsNowIsIncluded() {
        let due = card(itemId: "item_eq", skill: .shadowing, dueOffset: 0)
        let plan = SessionPlanner.plan(dueCards: [due], newLesson: nil, now: now)
        #expect(plan.reviews.map(\.itemId) == ["item_eq"])
    }

    @Test("relearnGateAt 未来は除外、ゲートちょうど now は含む")
    func relearnGateBoundary() {
        let gated = card(itemId: "gated", skill: .shadowing, dueOffset: -60, gateOffset: 60)
        let open = card(itemId: "open", skill: .shadowing, dueOffset: -60, gateOffset: 0)
        let plan = SessionPlanner.plan(dueCards: [gated, open], newLesson: nil, now: now)
        #expect(plan.reviews.map(\.itemId) == ["open"])
    }

    @Test("上限 20 で切って deferredDueCount が正しい")
    func maxReviewsCutsAndCountsDeferred() {
        let cards = (0..<21).map { index in
            card(
                itemId: String(format: "item_%02d", index),
                skill: .shadowing,
                dueOffset: TimeInterval(-100 + index)
            )
        }
        let plan = SessionPlanner.plan(
            dueCards: cards,
            newLesson: nil,
            now: now,
            policy: .standard
        )
        #expect(plan.reviews.count == 20)
        #expect(plan.deferredDueCount == 1)
    }

    @Test("並び: dueAt 昇順 → 同時刻 composition 優先 → itemId 昇順")
    func deterministicOrdering() {
        let later = card(itemId: "z_late", skill: .composition, dueOffset: 0)
        let earlyB = card(itemId: "b_item", skill: .shadowing, dueOffset: -30)
        let earlyA = card(itemId: "a_item", skill: .shadowing, dueOffset: -30)
        let earlyComp = card(itemId: "m_item", skill: .composition, dueOffset: -30)
        let plan = SessionPlanner.plan(
            dueCards: [later, earlyB, earlyA, earlyComp],
            newLesson: nil,
            now: now
        )
        #expect(plan.reviews.map(\.itemId) == ["m_item", "a_item", "b_item", "z_late"])
    }

    @Test("includeNewLesson=false で newLesson が落ちる")
    func excludeNewLesson() {
        let due = card(itemId: "item_1", skill: .shadowing, dueOffset: -10)
        let plan = SessionPlanner.plan(
            dueCards: [due],
            newLesson: sampleLesson,
            now: now,
            policy: SessionPlanPolicy(maxReviews: 20, includeNewLesson: false)
        )
        #expect(plan.newLesson == nil)
        #expect(plan.reviews.count == 1)
        #expect(plan.isEmpty == false)
    }

    @Test("失敗カードは dueAt が翌学習日でもゲート到達で同日再挑戦できる")
    func failedCardSameDayRetryWhenGatePassed() {
        let failed = card(
            itemId: "failed_retry",
            skill: .shadowing,
            dueOffset: 86_400,
            gateOffset: 0
        )
        let stillGated = card(
            itemId: "still_gated",
            skill: .shadowing,
            dueOffset: 86_400,
            gateOffset: 60
        )
        let plan = SessionPlanner.plan(dueCards: [failed, stillGated], newLesson: nil, now: now)
        #expect(plan.reviews.map(\.itemId) == ["failed_retry"])
    }

    @Test("同一 itemId・別 courseId は入力順に依らず courseId 昇順")
    func sameItemIdDifferentCourseIdIsDeterministic() {
        let courseB = card(itemId: "shared", skill: .shadowing, dueOffset: -10, courseId: "course_b")
        let courseA = card(itemId: "shared", skill: .shadowing, dueOffset: -10, courseId: "course_a")
        let forward = SessionPlanner.plan(dueCards: [courseA, courseB], newLesson: nil, now: now)
        let reversed = SessionPlanner.plan(dueCards: [courseB, courseA], newLesson: nil, now: now)
        #expect(forward.reviews.map(\.courseId) == ["course_a", "course_b"])
        #expect(reversed.reviews.map(\.courseId) == ["course_a", "course_b"])
        #expect(forward.reviews.map(\.cardKey) == reversed.reviews.map(\.cardKey))
    }

    @Test("due 21 件 + 新規ありの合成")
    func twentyOneDuePlusNewLesson() {
        let cards = (0..<21).map { index in
            card(
                itemId: String(format: "d_%02d", index),
                skill: index.isMultiple(of: 2) ? .composition : .shadowing,
                dueOffset: TimeInterval(-200 + index)
            )
        }
        let plan = SessionPlanner.plan(dueCards: cards, newLesson: sampleLesson, now: now)
        #expect(plan.reviews.count == 20)
        #expect(plan.deferredDueCount == 1)
        #expect(plan.newLesson == sampleLesson)
        #expect(plan.isEmpty == false)
    }
}
