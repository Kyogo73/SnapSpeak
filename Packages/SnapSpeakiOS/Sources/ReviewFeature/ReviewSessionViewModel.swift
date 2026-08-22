import Analytics
import ContentCore
import ContentKit
import Foundation
import HabitKit

@MainActor
public final class ReviewSessionViewModel: ObservableObject {
    public enum Phase: Equatable {
        case loading
        case newLessonIntro
        case running(index: Int, total: Int)
        case summary
    }

    @Published public private(set) var phase: Phase = .loading
    @Published public private(set) var entries: [ReviewEntry] = []
    @Published public private(set) var completedCount: Int = 0
    @Published public private(set) var skippedMissingCount: Int = 0
    @Published public private(set) var skippedByUserCount: Int = 0

    private let plan: SessionPlan
    private let courseStore: CourseStore
    private let analytics: any AnalyticsClient
    private var startedAt = Date()
    private var lastAdvancedIndex: Int?
    private var introConsumed = false
    private var pendingIndexAfterIntro = 0

    public init(plan: SessionPlan, courseStore: CourseStore, analytics: any AnalyticsClient) {
        self.plan = plan
        self.courseStore = courseStore
        self.analytics = analytics
    }

    public var current: ReviewEntry? {
        guard case let .running(index, _) = phase, entries.indices.contains(index) else {
            return nil
        }
        return entries[index]
    }

    public func load() async {
        phase = .loading
        startedAt = Date()
        let courses = await courseStore.allCourses()
        let resolved = Self.resolveEntries(plan: plan, courses: courses)
        entries = resolved.entries
        skippedMissingCount = resolved.skipped
        skippedByUserCount = 0
        let newCount = plan.newLesson == nil ? 0 : 1
        analytics.track(.reviewSessionStarted(dueCount: plan.reviews.count, newCount: newCount))
        begin(at: 0)
    }

    /// 新規レッスン区切りの続行。Item 完了とは別経路（二重タップで未実施 Item を飛ばさない）。
    public func continueNewLesson() {
        guard case .newLessonIntro = phase else { return }
        guard !introConsumed else { return }
        introConsumed = true
        phase = .running(index: pendingIndexAfterIntro, total: entries.count)
    }

    /// アイテム完了時に AppFeature 側から呼ばれる（既存 UseCase が永続化済み）。
    public func advance() {
        finishCurrentItem(countingAsCompleted: true)
    }

    /// マイク拒否などのスキップ。Attempt なし。completedCount には入れない。
    public func skip() {
        finishCurrentItem(countingAsCompleted: false)
    }

    /// 解決済み entries から intro / running を開始する（hostless テスト用）。
    public func startResolved(entries: [ReviewEntry], skipped: Int = 0) {
        self.entries = entries
        skippedMissingCount = skipped
        skippedByUserCount = 0
        completedCount = 0
        lastAdvancedIndex = nil
        introConsumed = false
        startedAt = Date()
        begin(at: 0)
    }

    private func begin(at index: Int) {
        if entries.isEmpty {
            trackCompleted()
            phase = .summary
        } else if shouldShowNewLessonIntro(beforeIndex: index) {
            pendingIndexAfterIntro = index
            introConsumed = false
            phase = .newLessonIntro
        } else {
            phase = .running(index: index, total: entries.count)
        }
    }

    private func finishCurrentItem(countingAsCompleted: Bool) {
        guard case let .running(index, total) = phase else { return }
        guard lastAdvancedIndex != index else { return }
        lastAdvancedIndex = index
        if countingAsCompleted {
            completedCount += 1
        } else {
            skippedByUserCount += 1
        }
        moveForward(from: index, total: total)
    }

    private func moveForward(from index: Int, total: Int) {
        let next = index + 1
        if next >= total {
            trackCompleted()
            phase = .summary
        } else if shouldShowNewLessonIntro(beforeIndex: next) {
            pendingIndexAfterIntro = next
            introConsumed = false
            phase = .newLessonIntro
        } else {
            phase = .running(index: next, total: total)
        }
    }

    nonisolated public static func shouldInsertNewLessonIntro(entries: [ReviewEntry], at index: Int) -> Bool {
        guard entries.indices.contains(index) else { return false }
        guard entries[index].origin == .newLesson else { return false }
        if index == 0 { return true }
        return entries[index - 1].origin != .newLesson
    }

    private func shouldShowNewLessonIntro(beforeIndex index: Int) -> Bool {
        Self.shouldInsertNewLessonIntro(entries: entries, at: index)
    }

    nonisolated public static func resolveEntries(
        plan: SessionPlan,
        courses: [StoredCourse]
    ) -> (entries: [ReviewEntry], skipped: Int) {
        var skipped = 0
        var entries: [ReviewEntry] = []
        var seenItemKeys = Set<String>()

        func locate(courseId: String, itemId: String) -> (lessonId: String, mode: LessonMode)? {
            for stored in courses where stored.course.id == courseId {
                for unit in stored.course.units {
                    for lesson in unit.lessons where lesson.items.contains(where: { $0.id == itemId }) {
                        return (lesson.id, lesson.mode)
                    }
                }
            }
            return nil
        }

        for card in plan.reviews {
            if let location = locate(courseId: card.courseId, itemId: card.itemId) {
                seenItemKeys.insert("\(card.courseId)|\(card.itemId)")
                entries.append(
                    ReviewEntry(
                        id: "\(card.courseId)/\(card.itemId)/due",
                        courseId: card.courseId,
                        lessonId: location.lessonId,
                        itemId: card.itemId,
                        mode: location.mode,
                        origin: .due(cardKey: card.cardKey)
                    )
                )
            } else {
                skipped += 1
            }
        }

        if let lesson = plan.newLesson {
            for itemId in lesson.itemIds {
                let key = "\(lesson.courseId)|\(itemId)"
                if seenItemKeys.contains(key) {
                    continue
                }
                if let location = locate(courseId: lesson.courseId, itemId: itemId) {
                    seenItemKeys.insert(key)
                    entries.append(
                        ReviewEntry(
                            id: "\(lesson.courseId)/\(itemId)/new",
                            courseId: lesson.courseId,
                            lessonId: lesson.lessonId,
                            itemId: itemId,
                            mode: location.mode,
                            origin: .newLesson
                        )
                    )
                } else {
                    skipped += 1
                }
            }
        }
        return (entries, skipped)
    }

    private func trackCompleted() {
        let durationMs = Int(Date().timeIntervalSince(startedAt) * 1_000)
        analytics.track(
            .reviewSessionCompleted(
                completedCount: completedCount,
                durationBand: Quantization.durationBand(ms: durationMs)
            )
        )
    }
}
