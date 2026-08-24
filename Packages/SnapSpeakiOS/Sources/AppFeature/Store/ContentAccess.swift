import ContentCore
import ContentKit

enum ContentAccess {
    static func isFirstUnit(course: Course, lessonId: String) -> Bool {
        guard let first = course.units.first else { return false }
        return first.lessons.contains { $0.id == lessonId }
    }

    static func isFirstUnit(courses: [StoredCourse], courseId: String, lessonId: String) -> Bool {
        guard let stored = courses.first(where: { $0.course.id == courseId }) else {
            return false
        }
        return isFirstUnit(course: stored.course, lessonId: lessonId)
    }

    static func access(
        resolver: EntitlementResolver,
        courses: [StoredCourse],
        courseId: String,
        lessonId: String,
        skillIsComposition: Bool
    ) -> EntitlementAccess {
        resolver.access(
            courseId: courseId,
            isFirstUnit: isFirstUnit(courses: courses, courseId: courseId, lessonId: lessonId),
            skillIsComposition: skillIsComposition
        )
    }

    static func access(
        resolver: EntitlementResolver,
        courses: [StoredCourse],
        coordinate: LessonCoordinate
    ) -> EntitlementAccess {
        access(
            resolver: resolver,
            courses: courses,
            courseId: coordinate.courseId,
            lessonId: coordinate.lessonId,
            skillIsComposition: coordinate.mode == .composition
        )
    }

    static func limitKind(resolver: EntitlementResolver, skillIsComposition: Bool) -> String {
        if skillIsComposition, resolver.compositionsUsedToday >= resolver.dailyCompositionLimit {
            return "composition"
        }
        return "unit"
    }
}
