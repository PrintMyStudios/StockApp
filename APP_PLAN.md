# Portfolio Hindsight - App Plan

> "Should I have just left it alone?" - The question every trader asks themselves

## The Problem

Existing stock apps are cluttered with market data, company analysis, and features aimed at active traders. But most people just want to know one simple thing: **Am I making good decisions, or would I be better off doing nothing?**

Your mum nailed it: this is about learning from your own behaviour, not analysing the market.

---

## Core Concept

**Portfolio Hindsight** is a personal trading analysis tool that:
1. Imports your transaction history (starting with Freetrade CSV)
2. Shows your portfolio value over time
3. Compares your actual performance against "what if I'd done nothing"
4. Helps you identify emotional or poorly-timed trades
5. Keeps it simple - no market noise, just YOUR data

---

## Key Features

### 1. CSV Import
- Upload transaction history from Freetrade
- Parse buys, sells, dividends
- Extensible to support other brokers later

### 2. Portfolio Timeline
- See your portfolio at any point in time
- Historical value based on actual stock prices at that time
- Clear visualisation of growth/decline

### 3. The "What If" Comparison
This is the killer feature:
- **Scenario A (Reality)**: Your actual portfolio with all trades
- **Scenario B (Do Nothing)**: What if you'd made your initial purchases and never touched it?
- **Scenario C (Custom)**: What if you'd skipped specific trades?

Visual comparison showing: "Your trading activity cost you £X" or "Your trading activity earned you an extra £X"

### 4. Trade Analysis
- Flag trades that were "emotional" (bought high, sold low)
- Show holding periods - did you panic sell?
- Identify your best and worst decisions

### 5. Simple Dashboard
- Current portfolio value
- Total invested vs current value
- Simple profit/loss percentage
- "Trading score" - are you beating the do-nothing strategy?

---

## User Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                         ONBOARDING                               │
├─────────────────────────────────────────────────────────────────┤
│  1. Welcome screen explaining the concept                        │
│  2. Import CSV from Freetrade (or manual entry)                  │
│  3. App fetches historical prices for holdings                   │
│  4. Dashboard ready                                              │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                         MAIN TABS                                │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│   [Dashboard]    [Timeline]    [Compare]    [Trades]             │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

---

## Screen Breakdown

### Tab 1: Dashboard
Simple, clean overview:
- **Portfolio Value**: £12,450
- **Total Invested**: £10,000
- **Profit/Loss**: +£2,450 (+24.5%)
- **vs Do-Nothing**: You're £340 behind (or ahead!)
- **Trading Score**: 🟡 Neutral (or 🟢 Good / 🔴 Poor)

### Tab 2: Timeline
- Interactive chart showing portfolio value over time
- Tap any date to see holdings on that day
- Toggle between:
  - Actual portfolio
  - "Do nothing" portfolio
  - Both overlaid

### Tab 3: Compare (The Magic)
- Side-by-side comparison
- Select date ranges
- "What if I hadn't made these trades?"
- Specific trade impact analysis

### Tab 4: Trades
- List of all transactions
- Each trade shows:
  - Date, stock, amount
  - Price then vs price now
  - Impact score (good/bad/neutral)
- Filter by: Winners, Losers, All

### Settings/Import
- Re-import CSV
- Add manual transactions
- Choose currency
- Dark/light mode

---

## Data Model

### Transaction
```swift
struct Transaction: Identifiable {
    let id: UUID
    let date: Date
    let type: TransactionType  // buy, sell, dividend
    let ticker: String
    let stockName: String
    let quantity: Double
    let pricePerShare: Double
    let totalAmount: Double
    let fees: Double?
}

enum TransactionType {
    case buy
    case sell
    case dividend
}
```

### Holding
```swift
struct Holding {
    let ticker: String
    let stockName: String
    let quantity: Double
    let averageCost: Double
    let currentPrice: Double

    var currentValue: Double { quantity * currentPrice }
    var costBasis: Double { quantity * averageCost }
    var profitLoss: Double { currentValue - costBasis }
    var profitLossPercent: Double { (profitLoss / costBasis) * 100 }
}
```

### PortfolioSnapshot
```swift
struct PortfolioSnapshot {
    let date: Date
    let holdings: [Holding]
    let totalValue: Double
    let totalCost: Double
}
```

### Scenario (for comparison)
```swift
struct Scenario {
    let name: String
    let description: String
    let transactions: [Transaction]  // which transactions are included
    let snapshots: [PortfolioSnapshot]  // calculated values over time
}
```

---

## CSV Import - Freetrade Format

Freetrade exports include columns like:
- Date
- Type (Buy/Sell/Dividend)
- Stock Name
- Ticker
- Quantity
- Price per share
- Total amount
- FX rate (for USD stocks)

```swift
struct FreetradeCVSParser {
    func parse(csvString: String) -> [Transaction] {
        // Parse CSV rows
        // Map to Transaction objects
        // Handle date formatting
        // Handle currency conversion
    }
}
```

---

## Stock Price API

For historical and current prices, options include:
1. **Yahoo Finance API** (unofficial but free)
2. **Alpha Vantage** (free tier available)
3. **Polygon.io** (generous free tier)
4. **IEX Cloud** (affordable)

Needed data:
- Current price for each holding
- Historical daily prices for comparison calculations

---

## The Comparison Algorithm

### "Do Nothing" Calculation

```
For each point in time:
  1. Take the initial portfolio (after first N days of buying)
  2. Calculate what it would be worth at that date
  3. Compare to actual portfolio value at same date

  "Do Nothing" scenario:
  - Include only the FIRST buy of each stock
  - OR include all buys up to a cut-off date
  - Never include any sells

  Difference = Actual Value - Do Nothing Value
  If negative: "Your trading cost you £X"
  If positive: "Your trading earned you £X"
```

### Trade Impact Score

For each sell:
```
Impact = (Price at Sell) - (Price Now) × Quantity

If Impact > 0: Good sell (price dropped after)
If Impact < 0: Bad sell (price rose after, you missed out)
```

For each buy after initial investment:
```
Impact = (Current Value of those shares) - (Amount spent)

If Impact > 0: Good buy
If Impact < 0: Bad buy (so far)
```

---

## Technical Architecture

### iOS App (SwiftUI)
```
StockApp/
├── App/
│   └── PortfolioHindsightApp.swift
├── Models/
│   ├── Transaction.swift
│   ├── Holding.swift
│   ├── PortfolioSnapshot.swift
│   └── Scenario.swift
├── Services/
│   ├── CSVParser.swift
│   ├── StockPriceService.swift
│   ├── PortfolioCalculator.swift
│   └── ComparisonEngine.swift
├── Views/
│   ├── Dashboard/
│   │   └── DashboardView.swift
│   ├── Timeline/
│   │   └── TimelineView.swift
│   ├── Compare/
│   │   └── CompareView.swift
│   ├── Trades/
│   │   └── TradesListView.swift
│   ├── Import/
│   │   └── ImportView.swift
│   └── Components/
│       ├── PortfolioChart.swift
│       ├── HoldingRow.swift
│       └── TradeImpactBadge.swift
├── ViewModels/
│   ├── DashboardViewModel.swift
│   ├── TimelineViewModel.swift
│   ├── CompareViewModel.swift
│   └── TradesViewModel.swift
└── Utilities/
    ├── DateFormatter+Extensions.swift
    └── NumberFormatter+Extensions.swift
```

### Data Persistence
- **SwiftData** (iOS 17+) for local storage
- Or Core Data for iOS 16 support
- Store: Transactions, cached prices, user preferences

### Async/Await
- Use Swift async/await for API calls
- Background refresh of stock prices

---

## Implementation Phases

### Phase 1: Foundation (MVP)
- [ ] Project setup with SwiftUI
- [ ] Data models
- [ ] Freetrade CSV parser
- [ ] Basic file import UI
- [ ] Local storage with SwiftData
- [ ] Simple transaction list view

### Phase 2: Portfolio Calculation
- [ ] Stock price API integration
- [ ] Current portfolio calculation
- [ ] Historical snapshot calculation
- [ ] Basic dashboard with current values

### Phase 3: Timeline & Visualisation
- [ ] Portfolio value chart (Swift Charts)
- [ ] Interactive timeline
- [ ] Date picker for snapshots
- [ ] Holdings breakdown view

### Phase 4: The Comparison Engine
- [ ] "Do Nothing" scenario calculation
- [ ] Side-by-side comparison view
- [ ] Trade impact scoring
- [ ] What-if analysis

### Phase 5: Polish & Insights
- [ ] Trading score algorithm
- [ ] Best/worst trades highlighting
- [ ] Emotional trade detection
- [ ] Dark mode
- [ ] Haptic feedback
- [ ] Empty states and onboarding

### Phase 6: Expansion (Future)
- [ ] Support for other brokers (Trading 212, Hargreaves Lansdown, etc.)
- [ ] Manual transaction entry
- [ ] iCloud sync
- [ ] Widgets
- [ ] Apple Watch companion

---

## Design Principles

1. **Clarity over completeness** - Show only what matters
2. **No market noise** - This is about YOUR decisions, not the market
3. **Honest feedback** - The app should tell you if you're making mistakes
4. **Non-judgmental** - Learning, not shaming
5. **Accessible** - Your mum should be able to use it easily

---

## Potential App Names

- Portfolio Hindsight
- Trade Mirror
- Portfolio Check
- Did I Do Good?
- Trade Tracker
- Hindsight
- My Trading Score

---

## Summary

This app answers one simple question: **"Am I a good trader, or should I just leave it alone?"**

It's not about beating the market or analysing companies. It's about self-awareness and learning from your own behaviour.

The killer feature is the comparison: showing users the exact pound difference between their actual trading activity and a simple "buy and hold" strategy.

Most people will discover they'd be better off doing nothing - and that's valuable knowledge!

---

## Next Steps

1. Set up the iOS project structure
2. Build the CSV parser for Freetrade
3. Create the core data models
4. Implement the comparison algorithm
5. Design the UI in Figma (optional)
6. Build screens incrementally

Ready to start building?
