import Analytics
import Foundation
import UserNotifications

/// `UNUserNotificationCenter.delegate` 用。着地は通常起動（ホーム）。ディープリンクはしない。
public final class ReminderDelegate: NSObject, UNUserNotificationCenterDelegate, @unchecked Sendable {
    private let analytics: any AnalyticsClient

    public init(analytics: any AnalyticsClient) {
        self.analytics = analytics
        super.init()
    }

    public func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let kind = response.notification.request.content.userInfo["kind"] as? String ?? "daily"
        analytics.track(.reminderOpened(kind: kind))
    }
}
