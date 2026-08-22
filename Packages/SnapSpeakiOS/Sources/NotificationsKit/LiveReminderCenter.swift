import Foundation
import UserNotifications

/// 状態を持たないため struct（nonisolated）。actor にすると UserNotifications の
/// 非 Sendable な戻り値（UNNotificationSettings 等）がアクター境界を越えられずコンパイル不可。
public struct LiveReminderCenter: ReminderCenter {
    public init() {}

    public func authorization() async -> ReminderAuthorization {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        switch settings.authorizationStatus {
        case .notDetermined:
            return .notDetermined
        case .denied:
            return .denied
        case .authorized, .provisional, .ephemeral:
            return .authorized
        @unknown default:
            return .denied
        }
    }

    public func requestAuthorization() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
        } catch {
            return false
        }
    }

    public func pendingIds() async -> [String] {
        let pending = await UNUserNotificationCenter.current().pendingNotificationRequests()
        return pending.map(\.identifier)
    }

    public func add(_ request: ReminderRequest) async throws {
        let content = UNMutableNotificationContent()
        content.title = request.title
        content.body = request.body
        content.userInfo = ["kind": request.kindRawValue]
        content.sound = .default

        let calendar = Calendar.current
        let matching = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: request.fireAt)
        let trigger = UNCalendarNotificationTrigger(dateMatching: matching, repeats: false)
        let notification = UNNotificationRequest(
            identifier: request.id,
            content: content,
            trigger: trigger
        )
        try await UNUserNotificationCenter.current().add(notification)
    }

    public func remove(ids: [String]) async {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
    }
}
