import Foundation

/// セッション内 Item の完了とスキップを分離する（スキップは completedCount に入れない）。
public struct ReviewItemCallbacks {
    public var complete: () -> Void
    public var skip: () -> Void

    public init(complete: @escaping () -> Void, skip: @escaping () -> Void) {
        self.complete = complete
        self.skip = skip
    }
}
