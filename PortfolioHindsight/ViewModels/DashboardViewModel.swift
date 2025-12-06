import Foundation
import SwiftUI
import SwiftData
import Observation

@Observable
final class DashboardViewModel {
    // State
    var holdings: [Holding] = []
    var totalValue: Double = 0
    var totalInvested: Double = 0
    var totalDividends: Double = 0
    var tradingScore: TradingScore?
    var doNothingValue: Double = 0
    var comparisonResult: ComparisonResult?
    var isLoading = false
    var error: Error?

    // Dependencies
    private var modelContext: ModelContext?
    private let priceService: StockPriceServiceProtocol

    init(priceService: StockPriceServiceProtocol = MockPriceService()) {
        self.priceService = priceService
    }

    func configure(with modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // Computed properties
    var profitLoss: Double {
        totalValue - totalInvested
    }

    var profitLossPercent: Double {
        guard totalInvested > 0 else { return 0 }
        return (profitLoss / totalInvested) * 100
    }

    var isProfit: Bool {
        profitLoss >= 0
    }

    var doNothingDifference: Double {
        totalValue - doNothingValue
    }

    var isBetterThanDoNothing: Bool {
        doNothingDifference >= 0
    }

    var topHoldings: [Holding] {
        Array(holdings.prefix(5))
    }

    var hasMoreHoldings: Bool {
        holdings.count > 5
    }

    var additionalHoldingsCount: Int {
        max(0, holdings.count - 5)
    }

    // Actions
    @MainActor
    func refresh(transactions: [Transaction]) async {
        isLoading = true
        error = nil

        defer { isLoading = false }

        guard !transactions.isEmpty else {
            reset()
            return
        }

        let calculator = PortfolioCalculator(priceService: priceService)
        let engine = ComparisonEngine(calculator: calculator)

        do {
            // Calculate current holdings
            holdings = try await calculator.calculateCurrentHoldings(from: transactions)
            totalValue = holdings.reduce(0) { $0 + $1.currentValue }
            totalInvested = calculator.calculateTotalInvested(from: transactions)
            totalDividends = calculator.calculateTotalDividends(from: transactions)

            // Calculate comparison
            let actual = try await engine.generateActualScenario(from: transactions)
            let doNothing = try await engine.generateDoNothingScenario(from: transactions)

            doNothingValue = doNothing.currentValue
            comparisonResult = ComparisonResult(actualScenario: actual, comparisonScenario: doNothing)

            // Calculate trading score
            tradingScore = engine.calculateTradingScore(
                actualValue: totalValue,
                doNothingValue: doNothingValue,
                totalInvested: totalInvested
            )
        } catch {
            self.error = error
            print("Dashboard refresh error: \(error)")
        }
    }

    private func reset() {
        holdings = []
        totalValue = 0
        totalInvested = 0
        totalDividends = 0
        tradingScore = nil
        doNothingValue = 0
        comparisonResult = nil
    }
}
