import SwiftUI
import SwiftData

struct InsightsView: View {
    @Query(sort: \Transaction.date) private var transactions: [Transaction]
    @State private var insights: [Insight] = []
    @State private var isLoading = true

    var body: some View {
        NavigationStack {
            ScrollView {
                if isLoading {
                    LoadingView("Analyzing your trades...")
                } else if insights.isEmpty {
                    EmptyStateView(
                        icon: "lightbulb",
                        title: "No Insights Yet",
                        description: "Import more transactions to get personalized insights"
                    )
                } else {
                    LazyVStack(spacing: 16) {
                        ForEach(insights) { insight in
                            InsightCard(insight: insight)
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Insights")
            .task {
                await generateInsights()
            }
        }
    }

    private func generateInsights() async {
        isLoading = true
        defer { isLoading = false }

        var newInsights: [Insight] = []

        // Analyze trading patterns
        let buys = transactions.filter { $0.type == .buy }
        let sells = transactions.filter { $0.type == .sell }

        // Insight: Holding period
        if !sells.isEmpty {
            let avgHoldingDays = calculateAverageHoldingPeriod()
            if avgHoldingDays < 30 {
                newInsights.append(Insight(
                    type: .warning,
                    title: "Short Holding Period",
                    description: "Your average holding period is \(avgHoldingDays) days. Short-term trading often underperforms buy-and-hold strategies.",
                    actionable: "Consider holding investments longer to reduce transaction costs and capture long-term growth."
                ))
            } else if avgHoldingDays > 365 {
                newInsights.append(Insight(
                    type: .positive,
                    title: "Patient Investor",
                    description: "Your average holding period is over a year. Long-term investing tends to outperform short-term trading.",
                    actionable: nil
                ))
            }
        }

        // Insight: Diversification
        let uniqueTickers = Set(transactions.map { $0.ticker })
        if uniqueTickers.count < 5 {
            newInsights.append(Insight(
                type: .info,
                title: "Limited Diversification",
                description: "You've invested in only \(uniqueTickers.count) stocks. Diversification can help reduce risk.",
                actionable: "Consider spreading investments across different sectors and asset types."
            ))
        } else if uniqueTickers.count > 20 {
            newInsights.append(Insight(
                type: .info,
                title: "Highly Diversified",
                description: "You own \(uniqueTickers.count) different stocks. Make sure you can track all of them effectively.",
                actionable: nil
            ))
        }

        // Insight: Sell timing
        if sells.count >= 3 {
            let badSells = countBadSells()
            let badSellPercent = Double(badSells) / Double(sells.count) * 100

            if badSellPercent > 50 {
                newInsights.append(Insight(
                    type: .warning,
                    title: "Sell Timing Issues",
                    description: "Over \(Int(badSellPercent))% of your sells were followed by price increases. You might be selling winners too early.",
                    actionable: "Consider setting target prices and sticking to them instead of emotional selling."
                ))
            } else if badSellPercent < 30 {
                newInsights.append(Insight(
                    type: .positive,
                    title: "Good Sell Timing",
                    description: "Most of your sells were well-timed. The prices often dropped after you sold.",
                    actionable: nil
                ))
            }
        }

        // Insight: Dividend income
        let dividends = transactions.filter { $0.type == .dividend }
        if dividends.count > 0 {
            let totalDividends = dividends.reduce(0) { $0 + $1.totalInBaseCurrency }
            newInsights.append(Insight(
                type: .positive,
                title: "Dividend Income",
                description: "You've received \(totalDividends.formatted(.currency(code: "GBP"))) in dividends from \(dividends.count) payments.",
                actionable: nil
            ))
        }

        // Insight: Trading frequency
        if let firstDate = transactions.first?.date {
            let daysSinceStart = Calendar.current.dateComponents([.day], from: firstDate, to: Date()).day ?? 1
            let tradesPerMonth = Double(buys.count + sells.count) / Double(daysSinceStart) * 30

            if tradesPerMonth > 10 {
                newInsights.append(Insight(
                    type: .warning,
                    title: "Frequent Trader",
                    description: "You're making about \(Int(tradesPerMonth)) trades per month. High trading frequency can hurt returns.",
                    actionable: "Each trade is a chance to make an emotional decision. Consider a more passive approach."
                ))
            }
        }

        // Insight: Best and worst trades
        if transactions.count >= 5 {
            if let bestTrade = findBestTrade() {
                newInsights.append(Insight(
                    type: .positive,
                    title: "Your Best Trade",
                    description: "Buying \(bestTrade.ticker) has been your best decision so far.",
                    actionable: nil
                ))
            }
        }

        insights = newInsights
    }

    private func calculateAverageHoldingPeriod() -> Int {
        var totalDays = 0
        var count = 0

        let sells = transactions.filter { $0.type == .sell }

        for sell in sells {
            // Find corresponding buy
            if let buy = transactions.first(where: {
                $0.ticker == sell.ticker && $0.type == .buy && $0.date < sell.date
            }) {
                let days = Calendar.current.dateComponents([.day], from: buy.date, to: sell.date).day ?? 0
                totalDays += days
                count += 1
            }
        }

        return count > 0 ? totalDays / count : 0
    }

    private func countBadSells() -> Int {
        // In a real app, this would compare sell price to current price
        // For demo, return a simulated value
        return transactions.filter { $0.type == .sell }.count / 3
    }

    private func findBestTrade() -> Transaction? {
        // In a real app, this would calculate actual returns
        return transactions.filter { $0.type == .buy }.first
    }
}

struct Insight: Identifiable {
    let id = UUID()
    let type: InsightType
    let title: String
    let description: String
    let actionable: String?
}

enum InsightType {
    case positive
    case warning
    case info

    var icon: String {
        switch self {
        case .positive: return "checkmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .info: return "info.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .positive: return .green
        case .warning: return .orange
        case .info: return .blue
        }
    }
}

struct InsightCard: View {
    let insight: Insight

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: insight.type.icon)
                    .foregroundStyle(insight.type.color)
                    .font(.title2)

                Text(insight.title)
                    .font(.headline)

                Spacer()
            }

            Text(insight.description)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if let actionable = insight.actionable {
                Divider()

                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "lightbulb.fill")
                        .foregroundStyle(.yellow)
                        .font(.caption)

                    Text(actionable)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

#Preview {
    InsightsView()
        .modelContainer(for: Transaction.self, inMemory: true)
}
