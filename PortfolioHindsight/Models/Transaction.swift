import Foundation
import SwiftData

/// Represents a single transaction (buy, sell, or dividend)
@Model
final class Transaction {
    var id: UUID
    var date: Date
    var type: TransactionType
    var ticker: String
    var stockName: String
    var quantity: Double
    var pricePerShare: Double
    var totalAmount: Double
    var fees: Double
    var currency: String
    var fxRate: Double  // For converting to base currency

    init(
        id: UUID = UUID(),
        date: Date,
        type: TransactionType,
        ticker: String,
        stockName: String,
        quantity: Double,
        pricePerShare: Double,
        totalAmount: Double,
        fees: Double = 0,
        currency: String = "GBP",
        fxRate: Double = 1.0
    ) {
        self.id = id
        self.date = date
        self.type = type
        self.ticker = ticker
        self.stockName = stockName
        self.quantity = quantity
        self.pricePerShare = pricePerShare
        self.totalAmount = totalAmount
        self.fees = fees
        self.currency = currency
        self.fxRate = fxRate
    }

    /// Total amount in base currency (GBP)
    var totalInBaseCurrency: Double {
        totalAmount * fxRate
    }
}

enum TransactionType: String, Codable, CaseIterable {
    case buy = "BUY"
    case sell = "SELL"
    case dividend = "DIVIDEND"

    var displayName: String {
        switch self {
        case .buy: return "Buy"
        case .sell: return "Sell"
        case .dividend: return "Dividend"
        }
    }

    var icon: String {
        switch self {
        case .buy: return "arrow.down.circle.fill"
        case .sell: return "arrow.up.circle.fill"
        case .dividend: return "banknote.fill"
        }
    }

    var color: String {
        switch self {
        case .buy: return "green"
        case .sell: return "red"
        case .dividend: return "blue"
        }
    }
}
