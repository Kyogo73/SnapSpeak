import Foundation
import SRSKit

/// SRSCardDTO から写像した、プラン生成に必要な最小情報（Persistence 非依存の Sendable 値）。
public struct DueCard: Sendable, Equatable, Hashable {
    public var cardKey: String
    public var courseId: String
    public var itemId: String
    public var skill: Skill
    public var dueAt: Date
    /// 失敗後 10 分ゲート（SRSState.relearnGateAt 由来）。nil はゲートなし。
    public var relearnGateAt: Date?

    public init(
        cardKey: String,
        courseId: String,
        itemId: String,
        skill: Skill,
        dueAt: Date,
        relearnGateAt: Date?
    ) {
        self.cardKey = cardKey
        self.courseId = courseId
        self.itemId = itemId
        self.skill = skill
        self.dueAt = dueAt
        self.relearnGateAt = relearnGateAt
    }

    func isDue(at now: Date) -> Bool {
        let gatePassed = relearnGateAt.map { now >= $0 } ?? true
        return gatePassed && now >= dueAt
    }
}

public struct SessionPlanPolicy: Sendable, Equatable, Hashable {
    /// 1 セッションの復習上限（タイムゾーンジャンプ時の due 一斉到来もこれで削る）。
    public var maxReviews: Int
    /// 新規レッスンをプランに含めるか。
    public var includeNewLesson: Bool

    public init(maxReviews: Int, includeNewLesson: Bool) {
        self.maxReviews = max(maxReviews, 0)
        self.includeNewLesson = includeNewLesson
    }

    public static let standard = SessionPlanPolicy(maxReviews: 20, includeNewLesson: true)
}

/// 「今日の学習」1 セッションの内容（ux-design §2.4）。
public struct SessionPlan: Sendable, Equatable, Hashable {
    /// 実施する復習。dueAt 昇順 → composition 優先 → itemId 昇順（決定的）。
    public var reviews: [DueCard]
    /// 上限で切った残り due 件数（「ほか n 件はまた明日」表示用）。
    public var deferredDueCount: Int
    /// コース順で次の未完了レッスン。なければ nil。
    public var newLesson: LessonSummary?

    public var isEmpty: Bool { reviews.isEmpty && newLesson == nil }

    public init(reviews: [DueCard], deferredDueCount: Int, newLesson: LessonSummary?) {
        self.reviews = reviews
        self.deferredDueCount = deferredDueCount
        self.newLesson = newLesson
    }
}

public enum SessionPlanner {
    /// due 判定と上限・並び順を適用してプランを組む純関数。
    /// due 条件: (relearnGateAt == nil || relearnGateAt <= now) && dueAt <= now
    ///（SRSKit `SRSState.isDue(at:)` と同義。カード側の値で再判定する）
    public static func plan(
        dueCards: [DueCard],
        newLesson: LessonSummary?,
        now: Date,
        policy: SessionPlanPolicy = .standard
    ) -> SessionPlan {
        let eligible = dueCards
            .filter { $0.isDue(at: now) }
            .sorted(by: Self.compareForPlan)
        let limit = policy.maxReviews
        let reviews = Array(eligible.prefix(limit))
        let deferred = max(eligible.count - reviews.count, 0)
        let lesson = policy.includeNewLesson ? newLesson : nil
        return SessionPlan(reviews: reviews, deferredDueCount: deferred, newLesson: lesson)
    }

    /// dueAt 昇順 → 同時刻は composition 優先 → itemId 昇順。
    static func compareForPlan(_ lhs: DueCard, _ rhs: DueCard) -> Bool {
        if lhs.dueAt != rhs.dueAt {
            return lhs.dueAt < rhs.dueAt
        }
        if lhs.skill != rhs.skill {
            if lhs.skill == .composition { return true }
            if rhs.skill == .composition { return false }
        }
        return lhs.itemId < rhs.itemId
    }
}
