import Foundation

/// Represents a hypothetical portfolio scenario for comparison
struct Scenario: Identifiable {
    let id: UUID
    let name: String
    let description: String
    let type: ScenarioType
    let dataPoints: [PortfolioDataPoint]

    init(
        id: UUID = UUID(),
        name: String,
        description: String,
        type: ScenarioType,
        dataPoints: [PortfolioDataPoint]
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.type = type
        self.dataPoints = dataPoints
    }

    /// Current/final value of this scenario
    var currentValue: Double {
        dataPoints.last?.value ?? 0
    }
}

enum ScenarioType: String, CaseIterable {
    case actual = "actual"
    case doNothing = "doNothing"
    case custom = "custom"

    var displayName: String {
        switch self {
        case .actual: return "Actual Portfolio"
        case .doNothing: return "Buy & Hold"
        case .custom: return "Custom Scenario"
        }
    }

    var color: String {
        switch self {
        case .actual: return "blue"
        case .doNothing: return "green"
        case .custom: return "orange"
        }
    }
}

/// Result of comparing two scenarios
struct ComparisonResult: Identifiable {
    let id: UUID
    let actualScenario: Scenario
    let comparisonScenario: Scenario
    let difference: Double
    let differencePercent: Double

    init(
        id: UUID = UUID(),
        actualScenario: Scenario,
        comparisonScenario: Scenario
    ) {
        self.id = id
        self.actualScenario = actualScenario
        self.comparisonScenario = comparisonScenario
        self.difference = actualScenario.currentValue - comparisonScenario.currentValue
        self.differencePercent = comparisonScenario.currentValue > 0
            ? (difference / comparisonScenario.currentValue) * 100
            : 0
    }

    /// Whether actual trading outperformed the comparison
    var isBetterOff: Bool {
        difference >= 0
    }

    /// Human-readable summary
    var summary: String {
        let formattedDiff = abs(difference).formatted(.currency(code: "GBP"))
        if isBetterOff {
            return "Your trading earned you an extra \(formattedDiff)"
        } else {
            return "Your trading cost you \(formattedDiff)"
        }
    }
}
