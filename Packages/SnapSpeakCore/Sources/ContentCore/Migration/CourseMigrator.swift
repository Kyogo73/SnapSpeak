import Foundation

/// Known vN → current internal `Course`. v1 is identity; v2 becomes the swap point.
public enum CourseMigrator {
    public static func migrate(_ course: CourseV1) -> Course {
        course
    }
}
