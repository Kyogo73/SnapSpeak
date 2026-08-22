import Foundation

/// seed / downloaded の同一 `courseId` を 1 本に正規化し、決定的な表示順にする。
public enum CourseCatalog: Sendable {
    /// `courseId` ごとに revision 最大を残し、`courseId` 昇順で返す。
    public static func uniquedActiveReleases<T>(
        _ items: [T],
        id: (T) -> String,
        revision: (T) -> Int
    ) -> [T] {
        var best: [String: T] = [:]
        for item in items {
            let key = id(item)
            if let existing = best[key], revision(existing) >= revision(item) {
                continue
            }
            best[key] = item
        }
        return best.values.sorted { lhs, rhs in
            if id(lhs) != id(rhs) {
                return id(lhs) < id(rhs)
            }
            return revision(lhs) > revision(rhs)
        }
    }
}
