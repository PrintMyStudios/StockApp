import SwiftUI
import Charts

struct PortfolioChartView: View {
    let dataPoints: [PortfolioDataPoint]
    let comparisonPoints: [PortfolioDataPoint]?
    let showComparison: Bool
    @Binding var selectedPoint: PortfolioDataPoint?

    init(
        dataPoints: [PortfolioDataPoint],
        comparisonPoints: [PortfolioDataPoint]? = nil,
        showComparison: Bool = false,
        selectedPoint: Binding<PortfolioDataPoint?> = .constant(nil)
    ) {
        self.dataPoints = dataPoints
        self.comparisonPoints = comparisonPoints
        self.showComparison = showComparison
        self._selectedPoint = selectedPoint
    }

    private var minValue: Double {
        let allPoints = dataPoints + (showComparison ? (comparisonPoints ?? []) : [])
        return (allPoints.min(by: { $0.value < $1.value })?.value ?? 0) * 0.95
    }

    private var maxValue: Double {
        let allPoints = dataPoints + (showComparison ? (comparisonPoints ?? []) : [])
        return (allPoints.max(by: { $0.value < $1.value })?.value ?? 0) * 1.05
    }

    var body: some View {
        Chart {
            // Main line
            ForEach(dataPoints) { point in
                LineMark(
                    x: .value("Date", point.date),
                    y: .value("Value", point.value),
                    series: .value("Series", "Portfolio")
                )
                .foregroundStyle(.blue)
                .lineStyle(StrokeStyle(lineWidth: 2))
                .interpolationMethod(.catmullRom)
            }

            // Area under main line
            ForEach(dataPoints) { point in
                AreaMark(
                    x: .value("Date", point.date),
                    y: .value("Value", point.value)
                )
                .foregroundStyle(
                    .linearGradient(
                        colors: [.blue.opacity(0.2), .blue.opacity(0.05)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .interpolationMethod(.catmullRom)
            }

            // Comparison line
            if showComparison, let comparison = comparisonPoints {
                ForEach(comparison) { point in
                    LineMark(
                        x: .value("Date", point.date),
                        y: .value("Value", point.value),
                        series: .value("Series", "Buy & Hold")
                    )
                    .foregroundStyle(.green)
                    .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 5]))
                    .interpolationMethod(.catmullRom)
                }
            }

            // Selected point indicator
            if let selected = selectedPoint {
                RuleMark(x: .value("Selected", selected.date))
                    .foregroundStyle(.gray.opacity(0.3))
                    .lineStyle(StrokeStyle(lineWidth: 1))

                PointMark(
                    x: .value("Date", selected.date),
                    y: .value("Value", selected.value)
                )
                .foregroundStyle(.blue)
                .symbolSize(100)
            }
        }
        .chartYScale(domain: minValue...maxValue)
        .chartXAxis {
            AxisMarks(preset: .aligned) { _ in
                AxisValueLabel(format: .dateTime.month(.abbreviated).day())
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisValueLabel {
                    if let doubleValue = value.as(Double.self) {
                        Text(formatCurrency(doubleValue))
                            .font(.caption2)
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
                    )
            }
        }
    }

    private func findClosestPoint(to date: Date) -> PortfolioDataPoint? {
        dataPoints.min(by: {
            abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date))
        })
    }

    private func formatCurrency(_ value: Double) -> String {
        if value >= 1000 {
            return "£\(Int(value / 1000))k"
        }
        return "£\(Int(value))"
    }
}

#Preview {
    let calendar = Calendar.current
    let now = Date()

    let sampleData = (0..<30).map { i in
        PortfolioDataPoint(
            date: calendar.date(byAdding: .day, value: -30 + i, to: now)!,
            value: Double.random(in: 9000...11000)
        )
    }

    return PortfolioChartView(
        dataPoints: sampleData,
        showComparison: false
    )
    .frame(height: 300)
    .padding()
}
