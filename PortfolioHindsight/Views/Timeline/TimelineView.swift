import SwiftUI
import SwiftData
import Charts

struct TimelineView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Transaction.date) private var transactions: [Transaction]

    @State private var dataPoints: [PortfolioDataPoint] = []
    @State private var selectedRange: TimeRange = .all
    @State private var selectedPoint: PortfolioDataPoint?
    @State private var isLoading = true

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Time range picker
                Picker("Time Range", selection: $selectedRange) {
                    ForEach(TimeRange.allCases, id: \.self) { range in
                        Text(range.label).tag(range)
                    }
                }
                .pickerStyle(.segmented)
                .padding()

                if isLoading {
                    Spacer()
                    ProgressView("Loading timeline...")
                    Spacer()
                } else if dataPoints.isEmpty {
                    Spacer()
                    ContentUnavailableView(
                        "No Data",
                        systemImage: "chart.xyaxis.line",
                        description: Text("Import your transactions to see your portfolio timeline")
                    )
                    Spacer()
                } else {
                    // Chart
                    Chart {
                        ForEach(filteredDataPoints) { point in
                            LineMark(
                                x: .value("Date", point.date),
                                y: .value("Value", point.value)
                            )
                            .foregroundStyle(.blue)
                            .interpolationMethod(.catmullRom)

                            AreaMark(
                                x: .value("Date", point.date),
                                y: .value("Value", point.value)
                            )
                            .foregroundStyle(
                                .linearGradient(
                                    colors: [.blue.opacity(0.3), .blue.opacity(0.05)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .interpolationMethod(.catmullRom)
                        }

                        if let selected = selectedPoint {
                            RuleMark(x: .value("Selected", selected.date))
                                .foregroundStyle(.gray.opacity(0.3))
                                .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))

                            PointMark(
                                x: .value("Date", selected.date),
                                y: .value("Value", selected.value)
                            )
                            .foregroundStyle(.blue)
                            .symbolSize(100)
                        }
                    }
                    .chartXAxis {
                        AxisMarks(preset: .aligned) { value in
                            AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                        }
                    }
                    .chartYAxis {
                        AxisMarks(position: .leading) { value in
                            AxisValueLabel {
                                if let doubleValue = value.as(Double.self) {
                                    Text(doubleValue.formatted(.currency(code: "GBP").precision(.fractionLength(0))))
                                }
                            }
                        }
                    }
                    .chartOverlay { proxy in
                        GeometryReader { geometry in
                            Rectangle()
                                .fill(.clear)
                                .contentShape(Rectangle())
                                .gesture(
                                    DragGesture(minimumDistance: 0)
                                        .onChanged { value in
                                            let x = value.location.x
                                            if let date: Date = proxy.value(atX: x) {
                                                selectedPoint = findClosestPoint(to: date)
                                            }
                                        }
                                        .onEnded { _ in
                                            // Keep selection visible
                                        }
                                )
                        }
                    }
                    .frame(height: 300)
                    .padding()

                    // Selected point details
                    if let selected = selectedPoint {
                        SelectedPointCard(point: selected)
                            .padding(.horizontal)
                    }

                    Spacer()

                    // Summary stats
                    SummaryStatsView(dataPoints: filteredDataPoints)
                        .padding()
                }
            }
            .navigationTitle("Timeline")
            .task {
                await loadTimeline()
            }
            .onChange(of: transactions.count) {
                Task { await loadTimeline() }
            }
        }
    }

    private var filteredDataPoints: [PortfolioDataPoint] {
        guard !dataPoints.isEmpty else { return [] }

        let calendar = Calendar.current
        let now = Date()

        let startDate: Date? = {
            switch selectedRange {
            case .week:
                return calendar.date(byAdding: .day, value: -7, to: now)
            case .month:
                return calendar.date(byAdding: .month, value: -1, to: now)
            case .threeMonths:
                return calendar.date(byAdding: .month, value: -3, to: now)
            case .year:
                return calendar.date(byAdding: .year, value: -1, to: now)
            case .all:
                return nil
            }
        }()

        if let startDate {
            return dataPoints.filter { $0.date >= startDate }
        }
        return dataPoints
    }

    private func findClosestPoint(to date: Date) -> PortfolioDataPoint? {
        filteredDataPoints.min(by: {
            abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date))
        })
    }

    private func loadTimeline() async {
        isLoading = true
        defer { isLoading = false }

        let calculator = PortfolioCalculator(priceService: MockPriceService())

        do {
            dataPoints = try await calculator.generateTimeline(from: Array(transactions), interval: .weekly)
        } catch {
            print("Error loading timeline: \(error)")
        }
    }
}

struct SelectedPointCard: View {
    let point: PortfolioDataPoint

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(point.date.formatted(date: .long, time: .omitted))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(point.value.formatted(.currency(code: "GBP")))
                    .font(.title2)
                    .fontWeight(.bold)
            }
            Spacer()
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct SummaryStatsView: View {
    let dataPoints: [PortfolioDataPoint]

    var startValue: Double {
        dataPoints.first?.value ?? 0
    }

    var endValue: Double {
        dataPoints.last?.value ?? 0
    }

    var change: Double {
        endValue - startValue
    }

    var changePercent: Double {
        guard startValue > 0 else { return 0 }
        return (change / startValue) * 100
    }

    var highValue: Double {
        dataPoints.max(by: { $0.value < $1.value })?.value ?? 0
    }

    var lowValue: Double {
        dataPoints.min(by: { $0.value < $1.value })?.value ?? 0
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                StatBox(title: "Start", value: startValue.formatted(.currency(code: "GBP")))
                StatBox(title: "Current", value: endValue.formatted(.currency(code: "GBP")))
                StatBox(
                    title: "Change",
                    value: "\(change >= 0 ? "+" : "")\(changePercent, specifier: "%.1f")%",
                    color: change >= 0 ? .green : .red
                )
            }

            HStack {
                StatBox(title: "High", value: highValue.formatted(.currency(code: "GBP")), color: .green)
                StatBox(title: "Low", value: lowValue.formatted(.currency(code: "GBP")), color: .red)
            }
        }
    }
}

struct StatBox: View {
    let title: String
    let value: String
    var color: Color = .primary

    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

enum TimeRange: CaseIterable {
    case week, month, threeMonths, year, all

    var label: String {
        switch self {
        case .week: return "1W"
        case .month: return "1M"
        case .threeMonths: return "3M"
        case .year: return "1Y"
        case .all: return "All"
        }
    }
}

#Preview {
    TimelineView()
        .modelContainer(for: Transaction.self, inMemory: true)
}
