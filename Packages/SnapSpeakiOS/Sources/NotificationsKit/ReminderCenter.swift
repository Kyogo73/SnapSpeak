import Foundation

public enum ReminderAuthorization: Sendable, Equatable {
    case notDetermined
    case denied
    case authorized
}

public struct ReminderRequest: Sendable, Equatable {
    public var id: String
    public var fireAt: Date
    public var title: String
    public var body: String
    /// analytics 用に userInfo へ入れる（reminder_opened の kind）。
    public var kindRawValue: String

    public init(id: String, fireAt: Date, title: String, body: String, kindRawValue: String) {
        self.id = id
        self.fireAt = fireAt
        self.title = title
        self.body = body
        self.kindRawValue = kindRawValue
    }
}

public protocol ReminderCenter: Sendable {
    func authorization() async -> ReminderAuthorization
    func requestAuthorization() async -> Bool
    func pendingIds() async -> [String]
    func add(_ request: ReminderRequest) async
    func remove(ids: [String]) async
}
