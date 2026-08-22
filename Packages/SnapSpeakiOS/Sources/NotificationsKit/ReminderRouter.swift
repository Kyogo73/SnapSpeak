import Combine
import Foundation

/// 通知タップでホームへ戻すための MainActor イベント。
@MainActor
public final class ReminderRouter: ObservableObject {
    @Published public private(set) var homeRevealToken = 0

    public init() {}

    public func revealHome() {
        homeRevealToken += 1
    }
}
