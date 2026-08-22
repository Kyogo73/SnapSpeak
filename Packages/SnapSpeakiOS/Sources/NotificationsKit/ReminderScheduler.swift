import Analytics
import Foundation
import HabitKit

public actor ReminderScheduler {
    private let center: any ReminderCenter
    private let analytics: any AnalyticsClient
    private var syncGeneration = 0

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
    /// 各 await 後に最新 generation か確認し、古い ON 同期が OFF 後に通知を足さない。
    /// 認可がない場合は何もしない。`add` 成功時のみ reminder_scheduled を track。
    public func sync(plan: [PlannedReminder], goalItems: Int) async {
        syncGeneration += 1
        let generation = syncGeneration
        guard await center.authorization() == .authorized else { return }
        guard generation == syncGeneration else { return }
        let pending = await center.pendingIds()
        guard generation == syncGeneration else { return }
        let reminderIds = pending.filter { $0.hasPrefix("reminder-") }
        if !reminderIds.isEmpty {
            await center.remove(ids: reminderIds)
        }
        guard generation == syncGeneration else { return }
        for item in plan {
            guard generation == syncGeneration else { return }
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
            do {
                try await center.add(request)
                guard generation == syncGeneration else {
                    await center.remove(ids: [request.id])
                    return
                }
                analytics.track(.reminderScheduled(kind: item.kind.rawValue))
            } catch {
                continue
            }
        }
    }
}
