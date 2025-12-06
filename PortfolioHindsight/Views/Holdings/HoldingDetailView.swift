import SwiftUI
import SwiftData
import Charts

struct HoldingDetailView: View {
    let holding: Holding
    @Query private var transactions: [Transaction]
    @State private var priceHistory: [PortfolioDataPoint] = []
    @State private var isLoading = true

    private var holdingTransactions: [Transaction] {
        transactions
            .filter { $0.ticker == holding.ticker }
            .sorted { $0.date > $1.date }
    }

    private var totalBought: Double {
        holdingTransactions
            .filter { $0.type == .buy }
            .reduce(0) { $0 + $1.quantity }
    }

    private var totalSold: Double {
        holdingTransactions
            .filter { $0.type == .sell }
            .reduce(0) { $0 + $1.quantity }
    }

    private var totalDividends: Double {
        holdingTransactions
            .filter { $0.type == .dividend }
            .reduce(0) { $0 + $1.totalInBaseCurrency }
    }

    private var firstPurchaseDate: Date? {
        holdingTransactions
            .filter { $0.type == .buy }
            .min { $0.date < $1.date }?.date
    }

    private var daysSinceFirstPurchase: Int {
        guard let firstDate = firstPurchaseDate else { return 0 }
        return Calendar.current.dateComponents([.day], from: firstDate, to: Date()).day ?? 0
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header card
                VStack(spacing: 16) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(holding.ticker)
                                .font(.title)
                                .fontWeight(.bold)
                            Text(holding.stockName)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }

                    Divider()

                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Current Value")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(holding.currentValue.formatted(.currency(code: "GBP")))
                                .font(.title2)
                                .fontWeight(.bold)
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 4) {
                            Text("Profit/Loss")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            HStack(spacing: 4) {
                                Image(systemName: holding.isProfit ? "arrow.up.right" : "arrow.down.right")
                                Text(holding.profitLoss.formatted(.currency(code: "GBP")))
                            }
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundStyle(holding.isProfit ? .green : .red)
                        }
                    }
                }
                .padding()
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 16))

                // Stats grid
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 12) {
                    StatCard(title: "Shares Owned", value: String(format: "%.2f", holding.quantity))
                    StatCard(title: "Avg Cost", value: holding.averageCost.formatted(.currency(code: "GBP")))
                    StatCard(title: "Current Price", value: holding.currentPrice.formatted(.currency(code: "GBP")))
                    StatCard(title: "Return", value: String(format: "%.1f%%", holding.profitLossPercent), color: holding.isProfit ? .green : .red)
                    StatCard(title: "Total Bought", value: String(format: "%.2f", totalBought))
                    StatCard(title: "Total Sold", value: String(format: "%.2f", totalSold))
                    StatCard(title: "Dividends", value: totalDividends.formatted(.currency(code: "GBP")))
                    StatCard(title: "Days Held", value: "\(daysSinceFirstPurchase)")
                }

                // Transaction history
                VStack(alignment: .leading, spacing: 12) {
                    Text("Transaction History")
                        .font(.headline)

                    ForEach(holdingTransactions) { transaction in
                        TransactionHistoryRow(transaction: transaction)
                    }
                }
                .padding()
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .padding()
        }
        .navigationTitle(holding.ticker)
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct StatCard: View {
    let title: String
    let value: String
    var color: Color = .primary

    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline)
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct TransactionHistoryRow: View {
    let transaction: Transaction

    var body: some View {
        HStack {
            Circle()
                .fill(typeColor.opacity(0.2))
                .frame(width: 40, height: 40)
                .overlay {
                    Image(systemName: transaction.type.icon)
                        .foregroundStyle(typeColor)
                }

            VStack(alignment: .leading, spacing: 2) {
                Text(transaction.type.displayName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(transaction.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(transaction.totalInBaseCurrency.formatted(.currency(code: "GBP")))
                    .font(.subheadline)
                    .fontWeight(.medium)
                if transaction.type != .dividend {
                    Text("\(transaction.quantity, specifier: "%.2f") @ \(transaction.pricePerShare, specifier: "%.2f")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }

    var typeColor: Color {
        switch transaction.type {
        case .buy: return .green
        case .sell: return .red
        case .dividend: return .blue
        }
    }
}

#Preview {
    NavigationStack {
        HoldingDetailView(holding: Holding(
            ticker: "AAPL",
            stockName: "Apple Inc",
            quantity: 10,
            averageCost: 145.50,
            currentPrice: 178.25
        ))
    }
    .modelContainer(for: Transaction.self, inMemory: true)
}
