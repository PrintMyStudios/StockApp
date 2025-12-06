import SwiftUI
import SwiftData

struct TradesListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Transaction.date, order: .reverse) private var transactions: [Transaction]

    @State private var filterType: TransactionTypeFilter = .all
    @State private var searchText = ""
    @State private var tradeImpacts: [UUID: TradeImpact] = [:]

    var filteredTransactions: [Transaction] {
        transactions.filter { transaction in
            // Type filter
            let typeMatch: Bool = {
                switch filterType {
                case .all: return true
                case .buys: return transaction.type == .buy
                case .sells: return transaction.type == .sell
                case .dividends: return transaction.type == .dividend
                }
            }()

            // Search filter
            let searchMatch = searchText.isEmpty ||
                transaction.ticker.localizedCaseInsensitiveContains(searchText) ||
                transaction.stockName.localizedCaseInsensitiveContains(searchText)

            return typeMatch && searchMatch
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Filter picker
                Picker("Filter", selection: $filterType) {
                    ForEach(TransactionTypeFilter.allCases, id: \.self) { filter in
                        Text(filter.label).tag(filter)
                    }
                }
                .pickerStyle(.segmented)
                .padding()

                if transactions.isEmpty {
                    ContentUnavailableView(
                        "No Trades",
                        systemImage: "list.bullet",
                        description: Text("Import your transaction history to see your trades")
                    )
                } else if filteredTransactions.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                } else {
                    List {
                        ForEach(groupedByMonth, id: \.key) { month, trades in
                            Section(month) {
                                ForEach(trades) { transaction in
                                    TransactionRow(
                                        transaction: transaction,
                                        impact: tradeImpacts[transaction.id]
                                    )
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Trades")
            .searchable(text: $searchText, prompt: "Search stocks")
            .task {
                await loadImpacts()
            }
        }
    }

    private var groupedByMonth: [(key: String, value: [Transaction])] {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"

        let grouped = Dictionary(grouping: filteredTransactions) { transaction in
            formatter.string(from: transaction.date)
        }

        return grouped.sorted { first, second in
            guard let firstDate = filteredTransactions.first(where: { formatter.string(from: $0.date) == first.key })?.date,
                  let secondDate = filteredTransactions.first(where: { formatter.string(from: $0.date) == second.key })?.date
            else { return false }
            return firstDate > secondDate
        }
    }

    private func loadImpacts() async {
        let priceService = MockPriceService()
        let calculator = PortfolioCalculator(priceService: priceService)
        let engine = ComparisonEngine(calculator: calculator)

        do {
            let impacts = try await engine.analyzeTradeImpacts(from: Array(transactions))
            for impact in impacts {
                tradeImpacts[impact.transaction.id] = impact
            }
        } catch {
            print("Error loading impacts: \(error)")
        }
    }
}

struct TransactionRow: View {
    let transaction: Transaction
    let impact: TradeImpact?

    var body: some View {
        HStack(spacing: 12) {
            // Type icon
            Image(systemName: transaction.type.icon)
                .font(.title2)
                .foregroundStyle(typeColor)
                .frame(width: 40, height: 40)
                .background(typeColor.opacity(0.15))
                .clipShape(Circle())

            // Transaction details
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(transaction.ticker)
                        .font(.headline)
                    Text(transaction.type.displayName)
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(typeColor.opacity(0.15))
                        .foregroundStyle(typeColor)
                        .clipShape(Capsule())
                }

                Text(transaction.stockName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Text(transaction.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            // Amount and impact
            VStack(alignment: .trailing, spacing: 4) {
                Text(transaction.totalInBaseCurrency.formatted(.currency(code: "GBP")))
                    .font(.subheadline)
                    .fontWeight(.medium)

                if transaction.type != .dividend {
                    Text("\(transaction.quantity, specifier: "%.2f") @ \(transaction.pricePerShare, specifier: "%.2f")")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                // Impact badge
                if let impact = impact {
                    ImpactBadge(impact: impact)
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

struct ImpactBadge: View {
    let impact: TradeImpact

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: impact.impactScore.icon)
                .font(.caption2)
            Text(impact.monetaryImpact >= 0 ? "+\(impact.monetaryImpact, specifier: "%.0f")" : "\(impact.monetaryImpact, specifier: "%.0f")")
                .font(.caption)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(badgeColor.opacity(0.15))
        .foregroundStyle(badgeColor)
        .clipShape(Capsule())
    }

    var badgeColor: Color {
        switch impact.impactScore {
        case .excellent: return .yellow
        case .good: return .green
        case .neutral: return .gray
        case .poor: return .red
        }
    }
}

enum TransactionTypeFilter: CaseIterable {
    case all, buys, sells, dividends

    var label: String {
        switch self {
        case .all: return "All"
        case .buys: return "Buys"
        case .sells: return "Sells"
        case .dividends: return "Dividends"
        }
    }
}

#Preview {
    TradesListView()
        .modelContainer(for: Transaction.self, inMemory: true)
}
