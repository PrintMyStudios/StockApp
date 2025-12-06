import Foundation

/// Calculates portfolio state from transactions
final class PortfolioCalculator {
    private let priceService: StockPriceServiceProtocol

    init(priceService: StockPriceServiceProtocol) {
        self.priceService = priceService
    }

    /// Calculate current holdings from all transactions
    func calculateCurrentHoldings(from transactions: [Transaction]) async throws -> [Holding] {
        // Group transactions by ticker
        let grouped = Dictionary(grouping: transactions) { $0.ticker }

        var holdings: [Holding] = []

        for (ticker, tickerTransactions) in grouped {
            // Calculate net position
            let buys = tickerTransactions.filter { $0.type == .buy }
            let sells = tickerTransactions.filter { $0.type == .sell }

            let totalBought = buys.reduce(0.0) { $0 + $1.quantity }
            let totalSold = sells.reduce(0.0) { $0 + $1.quantity }
            let netQuantity = totalBought - totalSold

            // Skip if no position
            guard netQuantity > 0.001 else { continue }

            // Calculate average cost (FIFO simplified to average)
            let totalCost = buys.reduce(0.0) { $0 + $1.totalInBaseCurrency }
            let averageCost = totalCost / totalBought

            // Get current price
            let currentPrice: Double
            do {
                currentPrice = try await priceService.getCurrentPrice(for: ticker)
            } catch {
                // Use last known price if current unavailable
                currentPrice = tickerTransactions.last?.pricePerShare ?? 0
            }

            let holding = Holding(
                ticker: ticker,
                stockName: tickerTransactions.first?.stockName ?? ticker,
                quantity: netQuantity,
                averageCost: averageCost,
                currentPrice: currentPrice
            )

            holdings.append(holding)
        }

        return holdings.sorted { $0.currentValue > $1.currentValue }
    }

    /// Calculate portfolio snapshot at a specific date
    func calculateSnapshot(
        from transactions: [Transaction],
        at date: Date
    ) async throws -> PortfolioSnapshot {
        // Filter transactions up to the date
        let relevantTransactions = transactions.filter { $0.date <= date }

        // Group by ticker
        let grouped = Dictionary(grouping: relevantTransactions) { $0.ticker }

        var holdings: [Holding] = []

        for (ticker, tickerTransactions) in grouped {
            let buys = tickerTransactions.filter { $0.type == .buy }
            let sells = tickerTransactions.filter { $0.type == .sell }

            let totalBought = buys.reduce(0.0) { $0 + $1.quantity }
            let totalSold = sells.reduce(0.0) { $0 + $1.quantity }
            let netQuantity = totalBought - totalSold

            guard netQuantity > 0.001 else { continue }

            let totalCost = buys.reduce(0.0) { $0 + $1.totalInBaseCurrency }
            let averageCost = totalCost / totalBought

            // Get historical price for this date
            let historicalPrice: Double
            do {
                historicalPrice = try await priceService.getHistoricalPrice(for: ticker, on: date)
            } catch {
                // Use transaction price as fallback
                historicalPrice = tickerTransactions.last?.pricePerShare ?? 0
            }

            let holding = Holding(
                ticker: ticker,
                stockName: tickerTransactions.first?.stockName ?? ticker,
                quantity: netQuantity,
                averageCost: averageCost,
                currentPrice: historicalPrice
            )

            holdings.append(holding)
        }

        return PortfolioSnapshot(date: date, holdings: holdings)
    }

    /// Generate portfolio value timeline
    func generateTimeline(
        from transactions: [Transaction],
        interval: TimelineInterval = .weekly
    ) async throws -> [PortfolioDataPoint] {
        guard let firstDate = transactions.first?.date,
              let lastDate = transactions.last?.date else {
            return []
        }

        let calendar = Calendar.current
        var dataPoints: [PortfolioDataPoint] = []
        var currentDate = firstDate

        while currentDate <= Date() {
            let snapshot = try await calculateSnapshot(from: transactions, at: currentDate)
            dataPoints.append(PortfolioDataPoint(date: currentDate, value: snapshot.totalValue))

            // Advance by interval
            switch interval {
            case .daily:
                currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
            case .weekly:
                currentDate = calendar.date(byAdding: .weekOfYear, value: 1, to: currentDate) ?? currentDate
            case .monthly:
                currentDate = calendar.date(byAdding: .month, value: 1, to: currentDate) ?? currentDate
            }
        }

        // Always include today
        if let lastPoint = dataPoints.last, !calendar.isDateInToday(lastPoint.date) {
            let todaySnapshot = try await calculateSnapshot(from: transactions, at: Date())
            dataPoints.append(PortfolioDataPoint(date: Date(), value: todaySnapshot.totalValue))
        }

        return dataPoints
    }

    /// Calculate total invested amount
    func calculateTotalInvested(from transactions: [Transaction]) -> Double {
        let buys = transactions.filter { $0.type == .buy }
        let sells = transactions.filter { $0.type == .sell }

        let totalBought = buys.reduce(0.0) { $0 + $1.totalInBaseCurrency }
        let totalSold = sells.reduce(0.0) { $0 + $1.totalInBaseCurrency }

        return totalBought - totalSold
    }

    /// Calculate total dividends received
    func calculateTotalDividends(from transactions: [Transaction]) -> Double {
        transactions
            .filter { $0.type == .dividend }
            .reduce(0.0) { $0 + $1.totalInBaseCurrency }
    }
}

enum TimelineInterval {
    case daily
    case weekly
    case monthly
}
