import Foundation
import SwiftUI
import Observation

@Observable
final class CompareViewModel {
    // State
    var actualScenario: Scenario?
    var doNothingScenario: Scenario?
    var comparisonResult: ComparisonResult?
    var showBothLines = true
    var selectedComparisonType: ComparisonType = .doNothing
    var isLoading = false
    var error: Error?

    // Dependencies
    private let priceService: StockPriceServiceProtocol

    init(priceService: StockPriceServiceProtocol = MockPriceService()) {
        self.priceService = priceService
    }

    // Computed properties
    var hasData: Bool {
        actualScenario != nil && doNothingScenario != nil
    }

    var actualCurrentValue: Double {
        actualScenario?.currentValue ?? 0
    }

    var comparisonCurrentValue: Double {
        doNothingScenario?.currentValue ?? 0
    }

    var difference: Double {
        actualCurrentValue - comparisonCurrentValue
    }

    var differencePercent: Double {
        guard comparisonCurrentValue > 0 else { return 0 }
        return (difference / comparisonCurrentValue) * 100
    }

    var isBetterOff: Bool {
        difference >= 0
    }

    var summaryMessage: String {
        let amount = abs(difference).formatted(.currency(code: "GBP"))
        if isBetterOff {
            return "Your trading earned you an extra \(amount)"
        } else {
            return "Your trading cost you \(amount)"
        }
    }

    // Actions
    @MainActor
    func loadComparison(from transactions: [Transaction]) async {
        isLoading = true
        error = nil
        defer { isLoading = false }

        guard !transactions.isEmpty else {
            actualScenario = nil
            doNothingScenario = nil
            comparisonResult = nil
            return
        }

        let calculator = PortfolioCalculator(priceService: priceService)
        let engine = ComparisonEngine(calculator: calculator)

        do {
            actualScenario = try await engine.generateActualScenario(from: transactions)
            doNothingScenario = try await engine.generateDoNothingScenario(from: transactions)

            if let actual = actualScenario, let doNothing = doNothingScenario {
                comparisonResult = ComparisonResult(actualScenario: actual, comparisonScenario: doNothing)
            }
        } catch {
            self.error = error
            print("Comparison load error: \(error)")
        }
    }
}

enum ComparisonType: String, CaseIterable {
    case doNothing = "Buy & Hold"
    case firstMonthOnly = "First Month Only"
    case noSells = "No Sells"

    var description: String {
        switch self {
        case .doNothing:
            return "What if you never sold anything?"
        case .firstMonthOnly:
            return "What if you only invested in the first month?"
        case .noSells:
            return "What if you never sold, but kept buying?"
        }
    }
}
