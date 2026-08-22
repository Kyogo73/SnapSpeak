import ContentCore
import Foundation

public struct ReviewEntry: Sendable, Equatable, Identifiable {
    public enum Origin: Sendable, Equatable {
        case due(cardKey: String)
        case newLesson
    }

    public var id: String
    public var courseId: String
    public var lessonId: String
    public var itemId: String
    public var mode: LessonMode
    public var origin: Origin

    public init(
        id: String,
        courseId: String,
        lessonId: String,
        itemId: String,
        mode: LessonMode,
        origin: Origin
    ) {
        self.id = id
        self.courseId = courseId
        self.lessonId = lessonId
        self.itemId = itemId
        self.mode = mode
        self.origin = origin
    }
}
