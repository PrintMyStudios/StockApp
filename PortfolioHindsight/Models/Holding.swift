import Foundation

/// Represents a current holding in the portfolio
struct Holding: Identifiable, Hashable {
    let id: UUID
    let ticker: String
    let stockName: String
    let quantity: Double
    let averageCost: Double
    let currentPrice: Double

    init(
        id: UUID = UUID(),
        ticker: String,
        stockName: String,
        quantity: Double,
        averageCost: Double,
        currentPrice: Double
    ) {
        self.id = id
        self.ticker = ticker
        self.stockName = stockName
        self.quantity = quantity
        self.averageCost = averageCost
        self.currentPrice = currentPrice
    }

    /// Current market value
    var currentValue: Double {
        quantity * currentPrice
    }

    /// Total cost basis
    var costBasis: Double {
        quantity * averageCost
    }

    /// Profit or loss in currency
    var profitLoss: Double {
        currentValue - costBasis
    }

    /// Profit or loss as percentage
    var profitLossPercent: Double {
        guard costBasis > 0 else { return 0 }
        return (profitLoss / costBasis) * 100
    }

    /// Whether this holding is in profit
    var isProfit: Bool {
        profitLoss >= 0
    }
}

extension Holding {
    /// Create a holding from a list of transactions for a single ticker
    static func from(transactions: [Transaction], currentPrice: Double) -> Holding? {
        let buyTransactions = transactions.filter { $0.type == .buy }
        let sellTransactions = transactions.filter { $0.type == .sell }

        guard let firstTransaction = transactions.first else { return nil }

        // Calculate total shares bought
        let totalBought = buyTransactions.reduce(0.0) { $0 + $1.quantity }
        let totalSold = sellTransactions.reduce(0.0) { $0 + $1.quantity }
        let currentQuantity = totalBought - totalSold

        guard currentQuantity > 0 else { return nil }

        // Calculate weighted average cost (only from buys)
        let totalCost = buyTransactions.reduce(0.0) { $0 + $1.totalInBaseCurrency }
        let averageCost = totalCost / totalBought

        return Holding(
            ticker: firstTransaction.ticker,
            stockName: firstTransaction.stockName,
            quantity: currentQuantity,
            averageCost: averageCost,
            currentPrice: currentPrice
        )
    }
}
