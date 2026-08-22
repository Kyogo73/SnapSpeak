import Foundation

/// seed / downloaded の同一 `courseId` を 1 本に正規化し、決定的な表示順にする。
public enum CourseCatalog: Sendable {
    /// `courseId` ごとに revision 最大を残し、`courseId` 昇順で返す。
    /// 同一 `courseId`・同一 `revision` は `releaseId` 非 nil（downloaded）を seed（nil）より優先し、
    /// 双方非 nil なら辞書順で大きい方、双方 nil なら先勝ち。
    public static func uniquedActiveReleases<T>(
        _ items: [T],
        id: (T) -> String,
        revision: (T) -> Int,
        releaseId: (T) -> String? = { _ in nil }
    ) -> [T] {
        var best: [String: T] = [:]
        for item in items {
            let key = id(item)
            if let existing = best[key],
               prefersExisting(existing, to: item, revision: revision, releaseId: releaseId) {
                continue
            }
            best[key] = item
        }
        return best.values.sorted { lhs, rhs in
            id(lhs) < id(rhs)
        }
    }

    /// 同一 id の既存を残すか。revision が大きい方、同点は releaseId で決定する。
    private static func prefersExisting<T>(
        _ existing: T,
        to incoming: T,
        revision: (T) -> Int,
        releaseId: (T) -> String?
    ) -> Bool {
        let existingRevision = revision(existing)
        let incomingRevision = revision(incoming)
        if existingRevision != incomingRevision {
            return existingRevision > incomingRevision
        }
        switch (releaseId(existing), releaseId(incoming)) {
        case (nil, .some):
            return false
        case (.some, nil):
            return true
        case let (.some(existingRelease), .some(incomingRelease)):
            return existingRelease >= incomingRelease
        case (nil, nil):
            return true
        }
    }
}
