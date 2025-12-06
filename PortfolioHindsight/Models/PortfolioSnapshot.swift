import Foundation

/// A snapshot of the portfolio at a specific point in time
struct PortfolioSnapshot: Identifiable {
    let id: UUID
    let date: Date
    let holdings: [Holding]

    init(id: UUID = UUID(), date: Date, holdings: [Holding]) {
        self.id = id
        self.date = date
        self.holdings = holdings
    }

    /// Total market value of all holdings
    var totalValue: Double {
        holdings.reduce(0) { $0 + $1.currentValue }
    }

    /// Total cost basis of all holdings
    var totalCost: Double {
        holdings.reduce(0) { $0 + $1.costBasis }
    }

    /// Total profit/loss
    var totalProfitLoss: Double {
        totalValue - totalCost
    }

    /// Total profit/loss as percentage
    var totalProfitLossPercent: Double {
        guard totalCost > 0 else { return 0 }
        return (totalProfitLoss / totalCost) * 100
    }

    /// Number of unique holdings
    var holdingsCount: Int {
        holdings.count
    }
}

/// Represents a data point for charting portfolio value over time
struct PortfolioDataPoint: Identifiable {
    let id: UUID
    let date: Date
    let value: Double

    init(id: UUID = UUID(), date: Date, value: Double) {
        self.id = id
        self.date = date
        self.value = value
    }
}
