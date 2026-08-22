import ContentCore
import Foundation

public struct LessonCoordinate: Hashable, Sendable {
    public var courseId: String
    public var lessonId: String
    public var itemId: String
    public var mode: LessonMode

    public init(courseId: String, lessonId: String, itemId: String, mode: LessonMode) {
        self.courseId = courseId
        self.lessonId = lessonId
        self.itemId = itemId
        self.mode = mode
    }
}

public enum HomeDestination: Hashable, Sendable {
    case lesson(LessonCoordinate)
    case review
}

public enum SettingsDestination: Hashable {
    case privacy
    case downloads
}

public enum AppTab: Hashable {
    case home
    case catalog
    case settings
}
