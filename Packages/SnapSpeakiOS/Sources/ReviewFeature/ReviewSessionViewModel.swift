import Analytics
import ContentCore
import ContentKit
import Foundation
import HabitKit

@MainActor
public final class ReviewSessionViewModel: ObservableObject {
    public enum Phase: Equatable {
        case loading
        case running(index: Int, total: Int)
        case summary
    }

    @Published public private(set) var phase: Phase = .loading
    @Published public private(set) var entries: [ReviewEntry] = []
    @Published public private(set) var completedCount: Int = 0
    @Published public private(set) var skippedCount: Int = 0

    private let plan: SessionPlan
    private let courseStore: CourseStore
    private let analytics: any AnalyticsClient
    private var startedAt = Date()

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
        skippedCount = resolved.skipped
        let newCount = plan.newLesson == nil ? 0 : 1
        analytics.track(.reviewSessionStarted(dueCount: plan.reviews.count, newCount: newCount))
        if entries.isEmpty {
            trackCompleted()
            phase = .summary
        } else {
            phase = .running(index: 0, total: entries.count)
        }
    }

    /// アイテム完了時に AppFeature 側から呼ばれる（既存 UseCase が永続化済み）。
    public func advance() {
        guard case let .running(index, total) = phase else { return }
        completedCount += 1
        let next = index + 1
        if next >= total {
            trackCompleted()
            phase = .summary
        } else {
            phase = .running(index: next, total: total)
        }
    }

    nonisolated public static func resolveEntries(
        plan: SessionPlan,
        courses: [StoredCourse]
    ) -> (entries: [ReviewEntry], skipped: Int) {
        var skipped = 0
        var entries: [ReviewEntry] = []

        func locate(courseId: String, itemId: String) -> (lessonId: String, mode: LessonMode)? {
            for stored in courses where stored.course.id == courseId {
                for unit in stored.course.units {
                    for lesson in unit.lessons {
                        if lesson.items.contains(where: { $0.id == itemId }) {
                            return (lesson.id, lesson.mode)
                        }
                    }
                }
            }
            return nil
        }

        for card in plan.reviews {
            if let location = locate(courseId: card.courseId, itemId: card.itemId) {
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
            let fallbackMode = LessonMode(rawValue: lesson.mode) ?? .shadowing
            for itemId in lesson.itemIds {
                if let location = locate(courseId: lesson.courseId, itemId: itemId) {
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
                    _ = fallbackMode
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
