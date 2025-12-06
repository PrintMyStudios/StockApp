import Foundation

/// Engine for comparing portfolio scenarios
final class ComparisonEngine {
    private let calculator: PortfolioCalculator

    init(calculator: PortfolioCalculator) {
        self.calculator = calculator
    }

    /// Generate the "Do Nothing" scenario
    /// This shows what would have happened if user only made initial purchases and never sold
    func generateDoNothingScenario(
        from transactions: [Transaction],
        cutoffDate: Date? = nil
    ) async throws -> Scenario {
        // Get only the first buy of each stock (or buys before cutoff)
        let initialBuys = extractInitialBuys(from: transactions, cutoff: cutoffDate)

        // Generate timeline for this scenario
        let dataPoints = try await calculator.generateTimeline(from: initialBuys)

        return Scenario(
            name: "Buy & Hold",
            description: "What if you never sold anything?",
            type: .doNothing,
            dataPoints: dataPoints
        )
    }

    /// Generate the actual portfolio scenario
    func generateActualScenario(from transactions: [Transaction]) async throws -> Scenario {
        let dataPoints = try await calculator.generateTimeline(from: transactions)

        return Scenario(
            name: "Actual Portfolio",
            description: "Your real trading history",
            type: .actual,
            dataPoints: dataPoints
        )
    }

    /// Generate a custom "What If" scenario excluding specific transactions
    func generateCustomScenario(
        from transactions: [Transaction],
        excluding excludedIds: Set<UUID>,
        name: String
    ) async throws -> Scenario {
        let filteredTransactions = transactions.filter { !excludedIds.contains($0.id) }

        // Validate the scenario makes sense (can't sell what you didn't buy)
        let validTransactions = validateTransactionSequence(filteredTransactions)

        let dataPoints = try await calculator.generateTimeline(from: validTransactions)

        return Scenario(
            name: name,
            description: "Custom scenario",
            type: .custom,
            dataPoints: dataPoints
        )
    }

    /// Compare actual vs do-nothing
    func compareWithDoNothing(transactions: [Transaction]) async throws -> ComparisonResult {
        let actualScenario = try await generateActualScenario(from: transactions)
        let doNothingScenario = try await generateDoNothingScenario(from: transactions)

        return ComparisonResult(
            actualScenario: actualScenario,
            comparisonScenario: doNothingScenario
        )
    }

    /// Analyze impact of individual trades
    func analyzeTradeImpacts(from transactions: [Transaction]) async throws -> [TradeImpact] {
        var impacts: [TradeImpact] = []

        // Get current prices for all tickers
        var currentPrices: [String: Double] = [:]
        let tickers = Set(transactions.map { $0.ticker })

        for ticker in tickers {
            do {
                // Note: In real implementation, would batch these requests
                let holdings = try await calculator.calculateCurrentHoldings(from: transactions.filter { $0.ticker == ticker })
                if let holding = holdings.first {
                    currentPrices[ticker] = holding.currentPrice
                }
            } catch {
                // Use last transaction price as fallback
                if let lastTx = transactions.filter({ $0.ticker == ticker }).last {
                    currentPrices[ticker] = lastTx.pricePerShare
                }
            }
        }

        for transaction in transactions {
            if let currentPrice = currentPrices[transaction.ticker] {
                let impact = TradeImpact(
                    transaction: transaction,
                    currentPrice: currentPrice
                )
                impacts.append(impact)
            }
        }

        return impacts.sorted { abs($0.monetaryImpact) > abs($1.monetaryImpact) }
    }

    /// Calculate trading score (0-100)
    /// Compares actual performance to do-nothing strategy
    func calculateTradingScore(
        actualValue: Double,
        doNothingValue: Double,
        totalInvested: Double
    ) -> TradingScore {
        guard doNothingValue > 0, totalInvested > 0 else {
            return TradingScore(score: 50, rating: .neutral, message: "Not enough data")
        }

        let actualReturn = (actualValue - totalInvested) / totalInvested
        let doNothingReturn = (doNothingValue - totalInvested) / totalInvested

        let outperformance = actualReturn - doNothingReturn

        // Score based on outperformance
        let score: Int
        let rating: TradingRating
        let message: String

        if outperformance > 0.1 {
            score = min(100, 75 + Int(outperformance * 100))
            rating = .excellent
            message = "You're beating buy-and-hold significantly!"
        } else if outperformance > 0.02 {
            score = 65 + Int(outperformance * 200)
            rating = .good
            message = "Your trading is adding value"
        } else if outperformance > -0.02 {
            score = 50
            rating = .neutral
            message = "You're about even with buy-and-hold"
        } else if outperformance > -0.1 {
            score = 35 + Int(outperformance * 200)
            rating = .poor
            message = "Buy-and-hold would be doing better"
        } else {
            score = max(0, 25 + Int(outperformance * 100))
            rating = .veryPoor
            message = "Your trading is hurting returns significantly"
        }

        return TradingScore(score: score, rating: rating, message: message)
    }

    // MARK: - Private Helpers

    private func extractInitialBuys(from transactions: [Transaction], cutoff: Date?) -> [Transaction] {
        let cutoffDate = cutoff ?? findInitialInvestmentPeriodEnd(transactions: transactions)

        // Get all buys before the cutoff
        var initialBuys = transactions.filter {
            $0.type == .buy && $0.date <= cutoffDate
        }

        // Also include dividends (reinvested or not)
        let dividends = transactions.filter { $0.type == .dividend }
        initialBuys.append(contentsOf: dividends)

        return initialBuys.sorted { $0.date < $1.date }
    }

    private func findInitialInvestmentPeriodEnd(transactions: [Transaction]) -> Date {
        // Find the first sell, or 30 days after first buy, whichever is earlier
        guard let firstBuy = transactions.first(where: { $0.type == .buy }) else {
            return Date()
        }

        let thirtyDaysLater = Calendar.current.date(byAdding: .day, value: 30, to: firstBuy.date) ?? firstBuy.date

        if let firstSell = transactions.first(where: { $0.type == .sell }) {
            return min(firstSell.date, thirtyDaysLater)
        }

        return thirtyDaysLater
    }

    private func validateTransactionSequence(_ transactions: [Transaction]) -> [Transaction] {
        // Ensure we can't sell more than we own
        var holdings: [String: Double] = [:]
        var validTransactions: [Transaction] = []

        for transaction in transactions.sorted(by: { $0.date < $1.date }) {
            switch transaction.type {
            case .buy:
                holdings[transaction.ticker, default: 0] += transaction.quantity
                validTransactions.append(transaction)

            case .sell:
                let owned = holdings[transaction.ticker, default: 0]
                if owned >= transaction.quantity {
                    holdings[transaction.ticker] = owned - transaction.quantity
                    validTransactions.append(transaction)
                }
                // Skip sell if we don't own enough

            case .dividend:
                validTransactions.append(transaction)
            }
        }

        return validTransactions
    }
}

struct TradingScore {
    let score: Int  // 0-100
    let rating: TradingRating
    let message: String
}

enum TradingRating {
    case excellent
    case good
    case neutral
    case poor
    case veryPoor

    var color: String {
        switch self {
        case .excellent: return "green"
        case .good: return "green"
        case .neutral: return "yellow"
        case .poor: return "orange"
        case .veryPoor: return "red"
        }
    }

    var icon: String {
        switch self {
        case .excellent: return "star.fill"
        case .good: return "hand.thumbsup.fill"
        case .neutral: return "minus.circle.fill"
        case .poor: return "hand.thumbsdown.fill"
        case .veryPoor: return "exclamationmark.triangle.fill"
        }
    }
}
