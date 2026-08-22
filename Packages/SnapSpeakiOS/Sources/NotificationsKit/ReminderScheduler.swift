import Analytics
import Foundation
import HabitKit

public actor ReminderScheduler {
    private let center: any ReminderCenter
    private let analytics: any AnalyticsClient

    public init(center: any ReminderCenter, analytics: any AnalyticsClient) {
        self.center = center
        self.analytics = analytics
    }

    public func authorization() async -> ReminderAuthorization {
        await center.authorization()
    }

    /// 未決定のときだけ OS ダイアログを出す。拒否でも throw しない（学習を止めない）。
    public func requestAuthorizationIfNeeded() async -> Bool {
        switch await center.authorization() {
        case .authorized:
            return true
        case .denied:
            return false
        case .notDetermined:
            return await center.requestAuthorization()
        }
    }

    /// "reminder-" prefix の pending を全消しして plan を登録する冪等同期。
    /// 認可がない場合は何もしない。登録成功ごとに reminder_scheduled を track。
    public func sync(plan: [PlannedReminder], goalItems: Int) async {
        guard await center.authorization() == .authorized else { return }
        let pending = await center.pendingIds()
        let reminderIds = pending.filter { $0.hasPrefix("reminder-") }
        if !reminderIds.isEmpty {
            await center.remove(ids: reminderIds)
        }
        for item in plan {
            let request = ReminderRequest(
                id: item.id,
                fireAt: item.fireAt,
                title: ReminderContent.title(kind: item.kind, streakDays: item.streakDays),
                body: ReminderContent.body(
                    kind: item.kind,
                    streakDays: item.streakDays,
                    goalItems: goalItems
                ),
                kindRawValue: item.kind.rawValue
            )
            await center.add(request)
            analytics.track(.reminderScheduled(kind: item.kind.rawValue))
        }
    }
}
