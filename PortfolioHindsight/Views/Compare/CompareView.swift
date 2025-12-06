import SwiftUI
import SwiftData
import Charts

struct CompareView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Transaction.date) private var transactions: [Transaction]

    @State private var actualScenario: Scenario?
    @State private var doNothingScenario: Scenario?
    @State private var comparisonResult: ComparisonResult?
    @State private var isLoading = true
    @State private var showBothLines = true

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    if isLoading {
                        ProgressView("Calculating scenarios...")
                            .padding(.top, 100)
                    } else if transactions.isEmpty {
                        ContentUnavailableView(
                            "No Trades Yet",
                            systemImage: "arrow.left.arrow.right",
                            description: Text("Import your transactions to compare your trading vs buy-and-hold")
                        )
                        .padding(.top, 100)
                    } else {
                        // Result summary card
                        if let result = comparisonResult {
                            ComparisonResultCard(result: result)
                        }

                        // Toggle for chart lines
                        Toggle("Show Both Strategies", isOn: $showBothLines)
                            .padding(.horizontal)

                        // Comparison chart
                        if let actual = actualScenario, let doNothing = doNothingScenario {
                            ComparisonChart(
                                actualScenario: actual,
                                doNothingScenario: doNothing,
                                showBoth: showBothLines
                            )
                        }

                        // Explanation card
                        ExplanationCard()

                        // What this means
                        if let result = comparisonResult {
                            InsightsCard(result: result)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Compare")
            .task {
                await loadComparison()
            }
            .onChange(of: transactions.count) {
                Task { await loadComparison() }
            }
        }
    }

    private func loadComparison() async {
        isLoading = true
        defer { isLoading = false }

        guard !transactions.isEmpty else { return }

        let priceService = MockPriceService()
        let calculator = PortfolioCalculator(priceService: priceService)
        let engine = ComparisonEngine(calculator: calculator)

        do {
            actualScenario = try await engine.generateActualScenario(from: Array(transactions))
            doNothingScenario = try await engine.generateDoNothingScenario(from: Array(transactions))

            if let actual = actualScenario, let doNothing = doNothingScenario {
                comparisonResult = ComparisonResult(actualScenario: actual, comparisonScenario: doNothing)
            }
        } catch {
            print("Error loading comparison: \(error)")
        }
    }
}

struct ComparisonResultCard: View {
    let result: ComparisonResult

    var body: some View {
        VStack(spacing: 16) {
            // Main result
            HStack {
                Image(systemName: result.isBetterOff ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                    .font(.largeTitle)
                    .foregroundStyle(result.isBetterOff ? .green : .red)

                VStack(alignment: .leading, spacing: 4) {
                    Text(result.isBetterOff ? "Your trading helped!" : "Buy & Hold wins")
                        .font(.headline)

                    Text(result.summary)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }

            Divider()

            // Comparison values
            HStack {
                VStack(spacing: 4) {
                    Text("Your Portfolio")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(result.actualScenario.currentValue.formatted(.currency(code: "GBP")))
                        .font(.headline)
                        .foregroundStyle(.blue)
                }

                Spacer()

                VStack(spacing: 4) {
                    Text("vs")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(result.difference >= 0 ? "+" : "")
                        + Text(result.difference.formatted(.currency(code: "GBP")))
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                .foregroundStyle(result.isBetterOff ? .green : .red)

                Spacer()

                VStack(spacing: 4) {
                    Text("Buy & Hold")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(result.comparisonScenario.currentValue.formatted(.currency(code: "GBP")))
                        .font(.headline)
                        .foregroundStyle(.green)
                }
            }
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

struct ComparisonChart: View {
    let actualScenario: Scenario
    let doNothingScenario: Scenario
    let showBoth: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Performance Over Time")
                .font(.headline)

            Chart {
                ForEach(actualScenario.dataPoints) { point in
                    LineMark(
                        x: .value("Date", point.date),
                        y: .value("Value", point.value),
                        series: .value("Scenario", "Actual")
                    )
                    .foregroundStyle(.blue)
                    .lineStyle(StrokeStyle(lineWidth: 2))
                }

                if showBoth {
                    ForEach(doNothingScenario.dataPoints) { point in
                        LineMark(
                            x: .value("Date", point.date),
                            y: .value("Value", point.value),
                            series: .value("Scenario", "Buy & Hold")
                        )
                        .foregroundStyle(.green)
                        .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 5]))
                    }
                }
            }
            .chartForegroundStyleScale([
                "Actual": Color.blue,
                "Buy & Hold": Color.green
            ])
            .chartLegend(position: .bottom)
            .frame(height: 250)

            // Legend
            HStack(spacing: 24) {
                LegendItem(color: .blue, label: "Your Portfolio", style: .solid)
                if showBoth {
                    LegendItem(color: .green, label: "Buy & Hold", style: .dashed)
                }
            }
            .font(.caption)
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

struct LegendItem: View {
    let color: Color
    let label: String
    let style: LegendStyle

    enum LegendStyle {
        case solid, dashed
    }

    var body: some View {
        HStack(spacing: 6) {
            Rectangle()
                .fill(color)
                .frame(width: 20, height: 3)
                .overlay {
                    if style == .dashed {
                        Rectangle()
                            .stroke(style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                            .foregroundStyle(.white)
                    }
                }
            Text(label)
                .foregroundStyle(.secondary)
        }
    }
}

struct ExplanationCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "lightbulb.fill")
                    .foregroundStyle(.yellow)
                Text("How This Works")
                    .font(.headline)
            }

            Text("**Buy & Hold** shows what your portfolio would be worth if you'd made your initial purchases and never sold anything.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text("The difference tells you whether your trading decisions are adding value or costing you money.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

struct InsightsCard: View {
    let result: ComparisonResult

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "brain")
                    .foregroundStyle(.purple)
                Text("What This Means")
                    .font(.headline)
            }

            if result.isBetterOff {
                Text("Your active trading is paying off! Your buy and sell decisions have outperformed a simple buy-and-hold strategy.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text("A buy-and-hold approach would have performed better. This is common - even professional traders struggle to beat the market.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Text("Consider whether emotional decisions (fear or excitement) led to trades that hurt your returns.")
                        .font(.subheadline)
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
    CompareView()
        .modelContainer(for: Transaction.self, inMemory: true)
}
