import Foundation
import SwiftUI
import Observation

@Observable
final class TimelineViewModel {
    // State
    var dataPoints: [PortfolioDataPoint] = []
    var doNothingDataPoints: [PortfolioDataPoint] = []
    var selectedRange: TimeRange = .all
    var selectedPoint: PortfolioDataPoint?
    var isLoading = false
    var showDoNothingLine = false
    var error: Error?

    // Dependencies
    private let priceService: StockPriceServiceProtocol

    init(priceService: StockPriceServiceProtocol = MockPriceService()) {
        self.priceService = priceService
    }

    // Computed properties
    var filteredDataPoints: [PortfolioDataPoint] {
        filterPoints(dataPoints)
    }

    var filteredDoNothingPoints: [PortfolioDataPoint] {
        filterPoints(doNothingDataPoints)
    }

    var startValue: Double {
        filteredDataPoints.first?.value ?? 0
    }

    var endValue: Double {
        filteredDataPoints.last?.value ?? 0
    }

    var valueChange: Double {
        endValue - startValue
    }

    var valueChangePercent: Double {
        guard startValue > 0 else { return 0 }
        return (valueChange / startValue) * 100
    }

    var highValue: Double {
        filteredDataPoints.max(by: { $0.value < $1.value })?.value ?? 0
    }

    var lowValue: Double {
        filteredDataPoints.min(by: { $0.value < $1.value })?.value ?? 0
    }

    var hasData: Bool {
        !dataPoints.isEmpty
    }

    // Actions
    @MainActor
    func loadTimeline(from transactions: [Transaction]) async {
        isLoading = true
        error = nil
        defer { isLoading = false }

        guard !transactions.isEmpty else {
            dataPoints = []
            doNothingDataPoints = []
            return
        }

        let calculator = PortfolioCalculator(priceService: priceService)
        let engine = ComparisonEngine(calculator: calculator)

        do {
            // Generate actual timeline
            dataPoints = try await calculator.generateTimeline(from: transactions, interval: .weekly)

            // Generate do-nothing timeline
            let doNothingScenario = try await engine.generateDoNothingScenario(from: transactions)
            doNothingDataPoints = doNothingScenario.dataPoints
        } catch {
            self.error = error
            print("Timeline load error: \(error)")
        }
    }

    func selectPoint(closestTo date: Date) {
        selectedPoint = filteredDataPoints.min(by: {
            abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date))
        })
    }

    func clearSelection() {
        selectedPoint = nil
    }

    // Private helpers
    private func filterPoints(_ points: [PortfolioDataPoint]) -> [PortfolioDataPoint] {
        guard !points.isEmpty else { return [] }

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
            return points.filter { $0.date >= startDate }
        }
        return points
    }
}
