import Foundation

extension Date {
    /// Check if this date is within the last N days
    func isWithinLast(days: Int) -> Bool {
        let calendar = Calendar.current
        guard let daysAgo = calendar.date(byAdding: .day, value: -days, to: Date()) else {
            return false
        }
        return self >= daysAgo
    }

    /// Get the start of this day
    var startOfDay: Date {
        Calendar.current.startOfDay(for: self)
    }

    /// Get the end of this day
    var endOfDay: Date {
        var components = DateComponents()
        components.day = 1
        components.second = -1
        return Calendar.current.date(byAdding: components, to: startOfDay) ?? self
    }

    /// Check if this date is on a weekend
    var isWeekend: Bool {
        Calendar.current.isDateInWeekend(self)
    }

    /// Check if this is a trading day (not weekend)
    var isTradingDay: Bool {
        !isWeekend
    }

    /// Get the previous trading day
    var previousTradingDay: Date {
        var date = Calendar.current.date(byAdding: .day, value: -1, to: self) ?? self
        while date.isWeekend {
            date = Calendar.current.date(byAdding: .day, value: -1, to: date) ?? date
        }
        return date
    }

    /// Format as relative date string
    func relativeFormatted() -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: self, relativeTo: Date())
    }

    /// Days between this date and another
    func daysSince(_ date: Date) -> Int {
        Calendar.current.dateComponents([.day], from: date, to: self).day ?? 0
    }

    /// Format for display in charts
    func chartFormatted() -> String {
        let formatter = DateFormatter()

        let daysSinceNow = Date().daysSince(self)

        if daysSinceNow < 7 {
            formatter.dateFormat = "E"  // Mon, Tue, etc.
        } else if daysSinceNow < 365 {
            formatter.dateFormat = "d MMM"  // 15 Jan
        } else {
            formatter.dateFormat = "MMM yy"  // Jan 24
        }

        return formatter.string(from: self)
    }
}
