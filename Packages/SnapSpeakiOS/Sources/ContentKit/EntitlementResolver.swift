import Foundation

public enum EntitlementAccess: String, Sendable, Equatable {
    case unlocked
    case locked
}

/// Phase 1 always unlocks. Phase 2 replaces this with StoreKit-backed resolution.
public struct EntitlementResolver: Sendable {
    public init() {}

    public func access(for courseId: String) -> EntitlementAccess {
        _ = courseId
        return .unlocked
    }
}
