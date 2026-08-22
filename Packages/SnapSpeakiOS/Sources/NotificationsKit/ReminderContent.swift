import Foundation
import HabitKit

public enum ReminderContent {
    public static func title(kind: ReminderKind, streakDays: Int) -> String {
        _ = streakDays
        switch kind {
        case .daily:
            return String(localized: String.LocalizationValue("notification.daily.title"), bundle: .main)
        case .streakRisk:
            return String(localized: String.LocalizationValue("notification.streak_risk.title"), bundle: .main)
        }
    }

    public static func body(kind: ReminderKind, streakDays: Int, goalItems: Int) -> String {
        switch kind {
        case .daily:
            let format = String(
                localized: String.LocalizationValue("notification.daily.body"),
                bundle: .main
            )
            return String(format: format, locale: .autoupdatingCurrent, goalItems)
        case .streakRisk:
            let format = String(
                localized: String.LocalizationValue("notification.streak_risk.body"),
                bundle: .main
            )
            return String(format: format, locale: .autoupdatingCurrent, streakDays)
        }
    }
}
