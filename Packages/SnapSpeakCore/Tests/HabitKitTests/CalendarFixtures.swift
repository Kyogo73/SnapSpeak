import Foundation

enum CalendarFixtures {
    static func calendar(timeZone: String) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: timeZone)!
        calendar.locale = Locale(identifier: "en_US_POSIX")
        return calendar
    }

    static func tokyo() -> Calendar {
        calendar(timeZone: "Asia/Tokyo")
    }

    static func losAngeles() -> Calendar {
        calendar(timeZone: "America/Los_Angeles")
    }

    static func london() -> Calendar {
        calendar(timeZone: "Europe/London")
    }

    static func date(
        _ year: Int,
        _ month: Int,
        _ day: Int,
        _ hour: Int,
        _ minute: Int,
        calendar: Calendar
    ) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        components.second = 0
        return calendar.date(from: components)!
    }
}
