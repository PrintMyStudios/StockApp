import Foundation

/// Analysis of how a specific trade impacted the portfolio
struct TradeImpact: Identifiable {
    let id: UUID
    let transaction: Transaction
    let currentPrice: Double
    let impactScore: ImpactScore

    init(
        id: UUID = UUID(),
        transaction: Transaction,
        currentPrice: Double
    ) {
        self.id = id
        self.transaction = transaction
        self.currentPrice = currentPrice
        self.impactScore = Self.calculateImpactScore(
            transaction: transaction,
            currentPrice: currentPrice
        )
    }

    /// The monetary impact of this trade
    var monetaryImpact: Double {
        switch transaction.type {
        case .buy:
            // For buys: current value - amount paid
            return (transaction.quantity * currentPrice) - transaction.totalInBaseCurrency
        case .sell:
            // For sells: amount received - what it would be worth now
            return transaction.totalInBaseCurrency - (transaction.quantity * currentPrice)
        case .dividend:
            // Dividends are always positive
            return transaction.totalInBaseCurrency
        }
    }

    /// Percentage return on this trade
    var percentageReturn: Double {
        guard transaction.totalInBaseCurrency > 0 else { return 0 }
        return (monetaryImpact / transaction.totalInBaseCurrency) * 100
    }

    private static func calculateImpactScore(
        transaction: Transaction,
        currentPrice: Double
    ) -> ImpactScore {
        let priceChange = currentPrice - transaction.pricePerShare
        let percentChange = (priceChange / transaction.pricePerShare) * 100

        switch transaction.type {
        case .buy:
            // Good buy if price went up
            if percentChange > 10 {
                return .excellent
            } else if percentChange > 0 {
                return .good
            } else if percentChange > -10 {
                return .neutral
            } else {
                return .poor
            }

        case .sell:
            // Good sell if price went down after
            if percentChange < -10 {
                return .excellent
            } else if percentChange < 0 {
                return .good
            } else if percentChange < 10 {
                return .neutral
            } else {
                return .poor  // Price went up, you sold too early
            }

        case .dividend:
            return .good  // Dividends are always nice
        }
    }
}

enum ImpactScore: String, CaseIterable {
    case excellent = "excellent"
    case good = "good"
    case neutral = "neutral"
    case poor = "poor"

    var displayName: String {
        switch self {
        case .excellent: return "Excellent"
        case .good: return "Good"
        case .neutral: return "Neutral"
        case .poor: return "Poor"
        }
    }

    var icon: String {
        switch self {
        case .excellent: return "star.fill"
        case .good: return "hand.thumbsup.fill"
        case .neutral: return "minus.circle.fill"
        case .poor: return "hand.thumbsdown.fill"
        }
    }

    var color: String {
        switch self {
        case .excellent: return "yellow"
        case .good: return "green"
        case .neutral: return "gray"
        case .poor: return "red"
        }
    }
}
