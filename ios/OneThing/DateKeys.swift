import Foundation

enum DateKeys {
    static let planPrefix = "onething-plan-"
    static let weekPrefix = "onething-week-"
    static let listKey = "onething-list"

    private static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.firstWeekday = 2
        return calendar
    }

    static func dayString(_ date: Date) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    static func planKey(_ date: Date) -> String {
        planPrefix + dayString(date)
    }

    static func weekKey(_ date: Date) -> String {
        weekPrefix + weekStartString(date)
    }

    static func weekStartString(_ date: Date) -> String {
        let start = calendar.dateInterval(of: .weekOfYear, for: date)?.start ?? date
        return dayString(start)
    }
}
