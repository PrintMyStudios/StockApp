# Portfolio Hindsight

A SwiftUI iOS app that helps users understand if their trading decisions are helping or hurting their returns.

## Project Overview

This app answers one question: **"Should I have just left it alone?"**

It imports transaction history from Freetrade (CSV), calculates portfolio performance over time, and compares actual results against a "buy and hold" strategy to show users the real impact of their trading decisions.

## Tech Stack

- **SwiftUI** - iOS 17+
- **SwiftData** - Local persistence
- **Swift Charts** - Data visualization
- **MVVM Architecture** - ViewModels for state management

## Project Structure

```
PortfolioHindsight/
├── App/                    # App entry point and main navigation
│   ├── PortfolioHindsightApp.swift
│   └── ContentView.swift   # Tab navigation, onboarding
├── Models/                 # Data models (SwiftData)
│   ├── Transaction.swift   # Core model: buys, sells, dividends
│   ├── Holding.swift       # Current portfolio position
│   ├── PortfolioSnapshot.swift
│   ├── Scenario.swift      # For comparison calculations
│   ├── TradeImpact.swift   # Individual trade analysis
│   └── CachedStockPrice.swift
├── Services/               # Business logic
│   ├── CSVParser.swift     # Freetrade CSV import
│   ├── StockPriceService.swift # Yahoo Finance API
│   ├── PortfolioCalculator.swift
│   └── ComparisonEngine.swift  # The "what if" magic
├── ViewModels/             # State management
│   ├── DashboardViewModel.swift
│   ├── TimelineViewModel.swift
│   ├── TradesViewModel.swift
│   └── CompareViewModel.swift
├── Views/
│   ├── Dashboard/          # Main portfolio overview
│   ├── Timeline/           # Interactive value chart
│   ├── Compare/            # Actual vs buy-and-hold
│   ├── Trades/             # Transaction list
│   ├── Import/             # CSV file picker
│   ├── Holdings/           # Individual stock details
│   ├── Insights/           # Trading behavior analysis
│   ├── Settings/           # App preferences
│   └── Components/         # Reusable UI components
├── Utilities/              # Extensions
└── Resources/              # Assets, Info.plist
```

## Key Concepts

### The Comparison Engine
The core feature compares two scenarios:
1. **Actual Portfolio** - User's real trading history
2. **Buy & Hold** - What if they never sold anything?

The difference shows whether active trading helped or hurt returns.

### Trading Score (0-100)
- Compares actual return vs buy-and-hold return
- \>70: Trading is adding value
- 50: About even
- <30: Buy-and-hold would be better

### CSV Import
Parses Freetrade exports with columns:
- Title, Type, Timestamp, Total Amount, Quantity, Ticker, etc.
- Handles GBP/USD with FX rates

## Build & Run

1. Open `PortfolioHindsight.xcodeproj` in Xcode 15+
2. Select iOS 17+ simulator
3. Run
4. Use "Load Demo Data" to test without real CSV

## Development Notes

### Adding a New Broker
1. Create a new parser implementing `CSVParserProtocol`
2. Add detection logic in `CSVParserFactory`
3. Update `ImportView` instructions

### Stock Price Service
Currently uses `MockPriceService` for development. To use real prices:
1. Replace with `YahooFinanceService`
2. Wrap with `CachedStockPriceService` for caching
3. Handle rate limiting and errors

### Testing
Demo data can be loaded from `ImportView.generateDemoTransactions()` for testing without importing real files.

## Common Tasks

### Add a new view
1. Create view in appropriate `Views/` subdirectory
2. Add corresponding ViewModel if needed
3. Wire up navigation in `ContentView.swift`

### Add a new model
1. Create in `Models/`
2. If persisted, add `@Model` and update schema in `PortfolioHindsightApp.swift`

### Modify comparison logic
- `ComparisonEngine.swift` contains all scenario generation
- `PortfolioCalculator.swift` handles holdings/timeline calculations

## Design Principles

1. **Simplicity** - Show only what matters, no market noise
2. **Honesty** - Tell users the truth about their trading
3. **Accessibility** - Should be usable by someone's mum
4. **Non-judgmental** - Learning, not shaming
