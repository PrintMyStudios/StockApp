import Foundation
import SwiftUI
import Observation

@Observable
final class TradesViewModel {
    // State
    var tradeImpacts: [UUID: TradeImpact] = [:]
    var filterType: TransactionTypeFilter = .all
    var searchText = ""
    var sortOrder: TradeSortOrder = .dateDescending
    var isLoading = false
    var error: Error?

    // Dependencies
    private let priceService: StockPriceServiceProtocol

    init(priceService: StockPriceServiceProtocol = MockPriceService()) {
        self.priceService = priceService
    }

    // Computed helpers
    func filteredTransactions(from transactions: [Transaction]) -> [Transaction] {
        var result = transactions

        // Apply type filter
        switch filterType {
        case .all:
            break
        case .buys:
            result = result.filter { $0.type == .buy }
        case .sells:
            result = result.filter { $0.type == .sell }
        case .dividends:
            result = result.filter { $0.type == .dividend }
        }

        // Apply search filter
        if !searchText.isEmpty {
            result = result.filter {
                $0.ticker.localizedCaseInsensitiveContains(searchText) ||
                $0.stockName.localizedCaseInsensitiveContains(searchText)
            }
        }

        // Apply sort
        switch sortOrder {
        case .dateDescending:
            result.sort { $0.date > $1.date }
        case .dateAscending:
            result.sort { $0.date < $1.date }
        case .amountDescending:
            result.sort { $0.totalInBaseCurrency > $1.totalInBaseCurrency }
        case .amountAscending:
            result.sort { $0.totalInBaseCurrency < $1.totalInBaseCurrency }
        case .impactDescending:
            result.sort { impact(for: $0) > impact(for: $1) }
        case .impactAscending:
            result.sort { impact(for: $0) < impact(for: $1) }
        }

        return result
    }

    func groupedByMonth(transactions: [Transaction]) -> [(key: String, value: [Transaction])] {
        let filtered = filteredTransactions(from: transactions)
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"

        let grouped = Dictionary(grouping: filtered) { transaction in
            formatter.string(from: transaction.date)
        }

        return grouped.sorted { first, second in
            guard let firstDate = filtered.first(where: { formatter.string(from: $0.date) == first.key })?.date,
                  let secondDate = filtered.first(where: { formatter.string(from: $0.date) == second.key })?.date
            else { return false }
            return firstDate > secondDate
        }
    }

    func impact(for transaction: Transaction) -> Double {
        tradeImpacts[transaction.id]?.monetaryImpact ?? 0
    }

    // Stats
    func stats(for transactions: [Transaction]) -> TradeStats {
        let filtered = filteredTransactions(from: transactions)

        let totalBuys = filtered.filter { $0.type == .buy }.reduce(0) { $0 + $1.totalInBaseCurrency }
        let totalSells = filtered.filter { $0.type == .sell }.reduce(0) { $0 + $1.totalInBaseCurrency }
        let totalDividends = filtered.filter { $0.type == .dividend }.reduce(0) { $0 + $1.totalInBaseCurrency }

        let goodTrades = filtered.filter { tradeImpacts[$0.id]?.impactScore == .good || tradeImpacts[$0.id]?.impactScore == .excellent }.count
        let poorTrades = filtered.filter { tradeImpacts[$0.id]?.impactScore == .poor }.count

        return TradeStats(
            totalBuys: totalBuys,
            totalSells: totalSells,
            totalDividends: totalDividends,
            transactionCount: filtered.count,
            goodTradeCount: goodTrades,
            poorTradeCount: poorTrades
        )
    }

    // Actions
    @MainActor
    func loadImpacts(from transactions: [Transaction]) async {
        isLoading = true
        defer { isLoading = false }

        let calculator = PortfolioCalculator(priceService: priceService)
        let engine = ComparisonEngine(calculator: calculator)

        do {
            let impacts = try await engine.analyzeTradeImpacts(from: transactions)
            for impact in impacts {
                tradeImpacts[impact.transaction.id] = impact
            }
        } catch {
            self.error = error
            print("Error loading impacts: \(error)")
        }
    }
}

enum TradeSortOrder: String, CaseIterable {
    case dateDescending = "Newest First"
    case dateAscending = "Oldest First"
    case amountDescending = "Largest First"
    case amountAscending = "Smallest First"
    case impactDescending = "Best Impact"
    case impactAscending = "Worst Impact"
}

struct TradeStats {
    let totalBuys: Double
    let totalSells: Double
    let totalDividends: Double
    let transactionCount: Int
    let goodTradeCount: Int
    let poorTradeCount: Int

    var netFlow: Double {
        totalSells + totalDividends - totalBuys
    }
}
