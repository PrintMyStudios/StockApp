import SwiftUI
import SwiftData
import Charts

struct DashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Transaction.date) private var transactions: [Transaction]

    @State private var holdings: [Holding] = []
    @State private var totalValue: Double = 0
    @State private var totalInvested: Double = 0
    @State private var tradingScore: TradingScore?
    @State private var doNothingValue: Double = 0
    @State private var isLoading = true
    @State private var showImport = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Main stats card
                    MainStatsCard(
                        totalValue: totalValue,
                        totalInvested: totalInvested,
                        profitLoss: totalValue - totalInvested
                    )

                    // Trading score
                    if let score = tradingScore {
                        TradingScoreCard(score: score, doNothingDiff: totalValue - doNothingValue)
                    }

                    // Holdings breakdown
                    if !holdings.isEmpty {
                        HoldingsCard(holdings: holdings)
                    }

                    // Quick stats
                    QuickStatsRow(
                        transactionCount: transactions.count,
                        holdingsCount: holdings.count,
                        dividends: transactions.filter { $0.type == .dividend }.reduce(0) { $0 + $1.totalInBaseCurrency }
                    )

                    // Insights link
                    if !transactions.isEmpty {
                        NavigationLink {
                            InsightsView()
                        } label: {
                            HStack {
                                Image(systemName: "lightbulb.fill")
                                    .foregroundStyle(.yellow)
                                Text("View Insights")
                                    .fontWeight(.medium)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding()
                            .background(.regularMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding()
            }
            .navigationTitle("Dashboard")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showImport = true
                    } label: {
                        Image(systemName: "square.and.arrow.down")
                    }
                }

                ToolbarItem(placement: .primaryAction) {
                    Button {
                        Task { await refreshData() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .sheet(isPresented: $showImport) {
                ImportView()
            }
            .overlay {
                if isLoading && !transactions.isEmpty {
                    ProgressView("Loading prices...")
                        .padding()
                        .background(.regularMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            .task {
                await refreshData()
            }
        }
    }

    private func refreshData() async {
        isLoading = true
        defer { isLoading = false }

        // For now, use mock calculations (real implementation would use price service)
        let calculator = PortfolioCalculator(priceService: MockPriceService())

        do {
            holdings = try await calculator.calculateCurrentHoldings(from: Array(transactions))
            totalValue = holdings.reduce(0) { $0 + $1.currentValue }
            totalInvested = calculator.calculateTotalInvested(from: Array(transactions))

            // Calculate trading score (simplified for demo)
            doNothingValue = totalValue * 1.05  // Mock: assume do-nothing would be 5% different
            tradingScore = TradingScore(score: 52, rating: .neutral, message: "You're about even with buy-and-hold")
        } catch {
            print("Error calculating portfolio: \(error)")
        }
    }
}

struct MainStatsCard: View {
    let totalValue: Double
    let totalInvested: Double
    let profitLoss: Double

    var profitLossPercent: Double {
        guard totalInvested > 0 else { return 0 }
        return (profitLoss / totalInvested) * 100
    }

    var isProfit: Bool { profitLoss >= 0 }

    var body: some View {
        VStack(spacing: 16) {
            Text("Portfolio Value")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text(totalValue.formatted(.currency(code: "GBP")))
                .font(.system(size: 36, weight: .bold, design: .rounded))

            HStack(spacing: 24) {
                VStack(spacing: 4) {
                    Text("Invested")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(totalInvested.formatted(.currency(code: "GBP")))
                        .font(.headline)
                }

                VStack(spacing: 4) {
                    Text("Profit/Loss")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack(spacing: 4) {
                        Image(systemName: isProfit ? "arrow.up.right" : "arrow.down.right")
                            .font(.caption)
                        Text(profitLoss.formatted(.currency(code: "GBP")))
                        Text("(\(profitLossPercent, specifier: "%.1f")%)")
                            .font(.caption)
                    }
                    .font(.headline)
                    .foregroundStyle(isProfit ? .green : .red)
                }
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

struct TradingScoreCard: View {
    let score: TradingScore
    let doNothingDiff: Double

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Trading Score")
                    .font(.headline)
                Spacer()
                Text("\(score.score)")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundStyle(scoreColor)
            }

            Text(score.message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            Divider()

            HStack {
                Text("vs Buy & Hold")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(doNothingDiff >= 0 ? "+\(doNothingDiff.formatted(.currency(code: "GBP")))" : doNothingDiff.formatted(.currency(code: "GBP")))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(doNothingDiff >= 0 ? .green : .red)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    var scoreColor: Color {
        switch score.rating {
        case .excellent, .good: return .green
        case .neutral: return .yellow
        case .poor, .veryPoor: return .red
        }
    }
}

struct HoldingsCard: View {
    let holdings: [Holding]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Holdings")
                .font(.headline)

            ForEach(holdings.prefix(5)) { holding in
                HoldingRow(holding: holding)
            }

            if holdings.count > 5 {
                Text("+ \(holdings.count - 5) more")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

struct HoldingRow: View {
    let holding: Holding

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(holding.ticker)
                    .font(.headline)
                Text(holding.stockName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(holding.currentValue.formatted(.currency(code: "GBP")))
                    .font(.subheadline)
                    .fontWeight(.medium)
                HStack(spacing: 2) {
                    Image(systemName: holding.isProfit ? "arrow.up.right" : "arrow.down.right")
                        .font(.caption2)
                    Text("\(holding.profitLossPercent, specifier: "%.1f")%")
                        .font(.caption)
                }
                .foregroundStyle(holding.isProfit ? .green : .red)
            }
        }
    }
}

struct QuickStatsRow: View {
    let transactionCount: Int
    let holdingsCount: Int
    let dividends: Double

    var body: some View {
        HStack(spacing: 16) {
            QuickStatItem(title: "Trades", value: "\(transactionCount)", icon: "arrow.left.arrow.right")
            QuickStatItem(title: "Holdings", value: "\(holdingsCount)", icon: "chart.pie")
            QuickStatItem(title: "Dividends", value: dividends.formatted(.currency(code: "GBP")), icon: "banknote")
        }
    }
}

struct QuickStatItem: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.blue)

            Text(value)
                .font(.headline)

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

/// Mock price service for demo/testing
class MockPriceService: StockPriceServiceProtocol {
    func getCurrentPrice(for ticker: String) async throws -> Double {
        // Return random-ish price based on ticker hash for consistency
        let base = Double(abs(ticker.hashValue) % 1000) / 10.0 + 10
        return base
    }

    func getHistoricalPrice(for ticker: String, on date: Date) async throws -> Double {
        let current = try await getCurrentPrice(for: ticker)
        // Add some variance for historical prices
        let daysSince = Calendar.current.dateComponents([.day], from: date, to: Date()).day ?? 0
        let variance = Double(daysSince) * 0.001
        return current * (1 - variance)
    }

    func getHistoricalPrices(for ticker: String, from startDate: Date, to endDate: Date) async throws -> [Date: Double] {
        var prices: [Date: Double] = [:]
        var date = startDate
        let calendar = Calendar.current

        while date <= endDate {
            prices[date] = try await getHistoricalPrice(for: ticker, on: date)
            date = calendar.date(byAdding: .day, value: 1, to: date) ?? endDate
        }

        return prices
    }
}

#Preview {
    DashboardView()
        .modelContainer(for: Transaction.self, inMemory: true)
}
