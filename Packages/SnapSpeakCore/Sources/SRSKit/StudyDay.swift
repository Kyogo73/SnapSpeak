import Foundation

public enum StudyDay: Sendable {
    public static let defaultBoundaryHour = 4
    public static let minimumRetryMinutes = 10

    /// Start of the study day containing `date` (local `dayBoundaryHour`:00).
    public static func studyDay(of date: Date, calendar: Calendar, dayBoundaryHour: Int = defaultBoundaryHour) -> Date {
        let hour = calendar.component(.hour, from: date)
        var day = calendar.startOfDay(for: date)
        if hour < dayBoundaryHour {
            guard let previous = calendar.date(byAdding: .day, value: -1, to: day) else { return day }
            day = previous
        }
        return calendar.date(bySettingHour: dayBoundaryHour, minute: 0, second: 0, of: day) ?? day
    }

    /// Success schedule: `intervalDays` study days after the review, aligned to the 04:00 boundary.
    public static func nextDueAt(
        intervalDays: Int,
        after reviewedAt: Date,
        calendar: Calendar,
        dayBoundaryHour: Int = defaultBoundaryHour
    ) -> Date {
        let start = studyDay(of: reviewedAt, calendar: calendar, dayBoundaryHour: dayBoundaryHour)
        return calendar.date(byAdding: .day, value: intervalDays, to: start) ?? start
    }

    /// Failure schedule: 10-minute cooldown plus next study-day 04:00 (both stored for the queue).
    public static func failureSchedule(
        after reviewedAt: Date,
        calendar: Calendar,
        dayBoundaryHour: Int = defaultBoundaryHour
    ) -> (retryNotBefore: Date, nextStudyDayDueAt: Date) {
        let retry = calendar.date(
            byAdding: .minute,
            value: minimumRetryMinutes,
            to: reviewedAt
        ) ?? reviewedAt.addingTimeInterval(TimeInterval(minimumRetryMinutes * 60))
        let current = studyDay(of: reviewedAt, calendar: calendar, dayBoundaryHour: dayBoundaryHour)
        let nextStudyDay = calendar.date(byAdding: .day, value: 1, to: current) ?? current
        return (retry, nextStudyDay)
    }
}
