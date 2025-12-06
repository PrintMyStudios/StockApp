import Foundation
import SwiftData

/// Cached stock price for offline access and reducing API calls
@Model
final class CachedStockPrice {
    var ticker: String
    var date: Date
    var closePrice: Double
    var currency: String
    var fetchedAt: Date

    init(
        ticker: String,
        date: Date,
        closePrice: Double,
        currency: String = "GBP",
        fetchedAt: Date = Date()
    ) {
        self.ticker = ticker
        self.date = date
        self.closePrice = closePrice
        self.currency = currency
        self.fetchedAt = fetchedAt
    }

    /// Check if this cached price is still valid (less than 24 hours old for current prices)
    var isValid: Bool {
        let calendar = Calendar.current
        let now = Date()

        // Historical prices are always valid
        if !calendar.isDateInToday(date) {
            return true
        }

        // Current day prices valid for 15 minutes during market hours
        let hoursSinceFetch = calendar.dateComponents([.hour], from: fetchedAt, to: now).hour ?? 0
        return hoursSinceFetch < 1
    }
}
