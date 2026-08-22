import Foundation

/// コース内アイテムの参照（courseId + itemId。itemId はコース内一意）。
public struct ItemRef: Hashable, Sendable {
    public var courseId: String
    public var itemId: String

    public init(courseId: String, itemId: String) {
        self.courseId = courseId
        self.itemId = itemId
    }
}

/// レッスンの骨格（ContentCore 非依存の写像。mode は "shadowing" | "composition" の生値）。
public struct LessonSummary: Sendable, Equatable, Hashable {
    public var courseId: String
    public var lessonId: String
    public var mode: String
    public var itemIds: [String]

    public init(courseId: String, lessonId: String, mode: String, itemIds: [String]) {
        self.courseId = courseId
        self.lessonId = lessonId
        self.mode = mode
        self.itemIds = itemIds
    }
}

public enum NextLessonSelector {
    /// カタログ順（Course → Unit → Lesson）の lessons から、
    /// 「全 Item に試行が付いていない」最初のレッスンを返す。全完了なら nil。
    /// itemIds が空のレッスンは完了扱いとしてスキップする。
    public static func next(
        lessons: [LessonSummary],
        attempted: Set<ItemRef>
    ) -> LessonSummary? {
        for lesson in lessons {
            if lesson.itemIds.isEmpty { continue }
            let incomplete = lesson.itemIds.contains { itemId in
                !attempted.contains(ItemRef(courseId: lesson.courseId, itemId: itemId))
            }
            if incomplete {
                return lesson
            }
        }
        return nil
    }
}
