import ContentCore
import ContentKit
import Foundation
import HabitKit
import Persistence
import SRSKit

public struct TodayPlanService: Sendable {
    public var persistence: PersistenceActor
    public var courseStore: CourseStore

    public init(persistence: PersistenceActor, courseStore: CourseStore) {
        self.persistence = persistence
        self.courseStore = courseStore
    }

    public func makeToday(
        now: Date,
        timeZone: TimeZone,
        goal: DailyGoal,
        policy: SessionPlanPolicy
    ) async throws -> TodaySnapshot {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        calendar.locale = Locale(identifier: "en_US_POSIX")

        let courses = await courseStore.allCourses()
        let cardDTOs = try await persistence.dueCards(now: now)
        let dueCards = cardDTOs.compactMap(Self.dueCard(from:))
        let activity = try await persistence.attemptActivityDates()
        let dayStart = StudyDay.studyDay(of: now, calendar: calendar)
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart
        let completed = try await persistence.attemptCount(from: dayStart, to: dayEnd)
        let attempted = try await persistence.attemptedItemRefs()
        let lessons = Self.lessonSummaries(from: courses)
        let newLesson = NextLessonSelector.next(lessons: lessons, attempted: attempted)
        let streak = StreakCalculator.snapshot(activity: activity, now: now, calendar: calendar)
        let progress = GoalEvaluator.progress(completedToday: completed, goal: goal)
        let plan = SessionPlanner.plan(dueCards: dueCards, newLesson: newLesson, now: now, policy: policy)
        return TodaySnapshot(
            streak: streak,
            goal: progress,
            plan: plan,
            hasCourses: !courses.isEmpty
        )
    }

    /// StoredCourse 列 → カタログ順 [LessonSummary]（ContentCore → HabitKit の写像）。
    public static func lessonSummaries(from courses: [StoredCourse]) -> [LessonSummary] {
        let unique = CourseCatalog.uniquedActiveReleases(
            courses,
            id: { $0.course.id },
            revision: { $0.revision },
            releaseId: { $0.releaseId }
        )
        var result: [LessonSummary] = []
        for stored in unique {
            for unit in stored.course.units {
                for lesson in unit.lessons {
                    result.append(
                        LessonSummary(
                            courseId: stored.course.id,
                            lessonId: lesson.id,
                            mode: lesson.mode.rawValue,
                            itemIds: lesson.items.map(\.id)
                        )
                    )
                }
            }
        }
        return result
    }

    /// SRSCardDTO → DueCard の写像（relearnGateAt を含む）。
    public static func dueCard(from dto: SRSCardDTO) -> DueCard? {
        guard let skill = Skill(rawValue: dto.skill) else { return nil }
        return DueCard(
            cardKey: dto.cardKey,
            courseId: dto.courseId,
            itemId: dto.itemId,
            skill: skill,
            dueAt: dto.dueAt,
            relearnGateAt: dto.relearnGateAt
        )
    }
}
