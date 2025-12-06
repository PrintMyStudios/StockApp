import Foundation
import SwiftData

/// Protocol for fetching stock prices
protocol StockPriceServiceProtocol {
    func getCurrentPrice(for ticker: String) async throws -> Double
    func getHistoricalPrice(for ticker: String, on date: Date) async throws -> Double
    func getHistoricalPrices(for ticker: String, from startDate: Date, to endDate: Date) async throws -> [Date: Double]
}

/// Errors from the stock price service
enum StockPriceError: LocalizedError {
    case networkError(Error)
    case invalidResponse
    case tickerNotFound(String)
    case noDataAvailable
    case rateLimited

    var errorDescription: String? {
        switch self {
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .invalidResponse:
            return "Invalid response from price service"
        case .tickerNotFound(let ticker):
            return "Ticker not found: \(ticker)"
        case .noDataAvailable:
            return "No price data available"
        case .rateLimited:
            return "Too many requests, please try again later"
        }
    }
}

/// Stock price service using Yahoo Finance API
final class YahooFinanceService: StockPriceServiceProtocol {
    private let session: URLSession
    private let baseURL = "https://query1.finance.yahoo.com/v8/finance/chart/"

    init(session: URLSession = .shared) {
        self.session = session
    }

    func getCurrentPrice(for ticker: String) async throws -> Double {
        let adjustedTicker = adjustTickerForYahoo(ticker)
        let url = URL(string: "\(baseURL)\(adjustedTicker)?interval=1d&range=1d")!

        let (data, response) = try await session.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw StockPriceError.invalidResponse
        }

        if httpResponse.statusCode == 429 {
            throw StockPriceError.rateLimited
        }

        guard httpResponse.statusCode == 200 else {
            throw StockPriceError.tickerNotFound(ticker)
        }

        return try parseCurrentPrice(from: data)
    }

    func getHistoricalPrice(for ticker: String, on date: Date) async throws -> Double {
        let adjustedTicker = adjustTickerForYahoo(ticker)

        // Get a range around the target date
        let calendar = Calendar.current
        let startDate = calendar.date(byAdding: .day, value: -5, to: date)!
        let endDate = calendar.date(byAdding: .day, value: 1, to: date)!

        let startTimestamp = Int(startDate.timeIntervalSince1970)
        let endTimestamp = Int(endDate.timeIntervalSince1970)

        let url = URL(string: "\(baseURL)\(adjustedTicker)?period1=\(startTimestamp)&period2=\(endTimestamp)&interval=1d")!

        let (data, response) = try await session.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw StockPriceError.tickerNotFound(ticker)
        }

        let prices = try parseHistoricalPrices(from: data)

        // Find closest date
        let targetDateStart = calendar.startOfDay(for: date)
        if let price = prices[targetDateStart] {
            return price
        }

        // Return most recent price before target date
        let sortedDates = prices.keys.sorted().reversed()
        for priceDate in sortedDates {
            if priceDate <= date {
                return prices[priceDate]!
            }
        }

        throw StockPriceError.noDataAvailable
    }

    func getHistoricalPrices(for ticker: String, from startDate: Date, to endDate: Date) async throws -> [Date: Double] {
        let adjustedTicker = adjustTickerForYahoo(ticker)

        let startTimestamp = Int(startDate.timeIntervalSince1970)
        let endTimestamp = Int(endDate.timeIntervalSince1970)

        let url = URL(string: "\(baseURL)\(adjustedTicker)?period1=\(startTimestamp)&period2=\(endTimestamp)&interval=1d")!

        let (data, response) = try await session.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw StockPriceError.tickerNotFound(ticker)
        }

        return try parseHistoricalPrices(from: data)
    }

    /// Adjust ticker symbols for Yahoo Finance format
    private func adjustTickerForYahoo(_ ticker: String) -> String {
        // UK stocks on LSE need .L suffix
        let ukSuffixes = [".L", ".LSE"]
        if ukSuffixes.contains(where: { ticker.uppercased().hasSuffix($0) }) {
            return ticker
        }

        // Common UK stocks that need .L
        let commonUKStocks = ["LLOY", "BARC", "HSBA", "VOD", "BP", "SHEL", "GSK", "AZN", "ULVR", "RIO"]
        if commonUKStocks.contains(ticker.uppercased()) {
            return "\(ticker.uppercased()).L"
        }

        return ticker.uppercased()
    }

    private func parseCurrentPrice(from data: Data) throws -> Double {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let chart = json["chart"] as? [String: Any],
              let result = (chart["result"] as? [[String: Any]])?.first,
              let meta = result["meta"] as? [String: Any],
              let price = meta["regularMarketPrice"] as? Double else {
            throw StockPriceError.invalidResponse
        }

        return price
    }

    private func parseHistoricalPrices(from data: Data) throws -> [Date: Double] {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let chart = json["chart"] as? [String: Any],
              let result = (chart["result"] as? [[String: Any]])?.first,
              let timestamps = result["timestamp"] as? [Int],
              let indicators = result["indicators"] as? [String: Any],
              let quote = (indicators["quote"] as? [[String: Any]])?.first,
              let closes = quote["close"] as? [Double?] else {
            throw StockPriceError.invalidResponse
        }

        var prices: [Date: Double] = [:]
        let calendar = Calendar.current

        for (index, timestamp) in timestamps.enumerated() {
            let date = Date(timeIntervalSince1970: TimeInterval(timestamp))
            let dayStart = calendar.startOfDay(for: date)

            if let close = closes[index] {
                prices[dayStart] = close
            }
        }

        return prices
    }
}

/// Caching wrapper around a stock price service
final class CachedStockPriceService: StockPriceServiceProtocol {
    private let wrapped: StockPriceServiceProtocol
    private let modelContext: ModelContext

    init(wrapped: StockPriceServiceProtocol, modelContext: ModelContext) {
        self.wrapped = wrapped
        self.modelContext = modelContext
    }

    func getCurrentPrice(for ticker: String) async throws -> Double {
        // Check cache first
        if let cached = try? getCachedPrice(ticker: ticker, date: Date()), cached.isValid {
            return cached.closePrice
        }

        // Fetch and cache
        let price = try await wrapped.getCurrentPrice(for: ticker)
        try cachePrice(ticker: ticker, date: Date(), price: price)
        return price
    }

    func getHistoricalPrice(for ticker: String, on date: Date) async throws -> Double {
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: date)

        // Check cache first
        if let cached = try? getCachedPrice(ticker: ticker, date: dayStart) {
            return cached.closePrice
        }

        // Fetch and cache
        let price = try await wrapped.getHistoricalPrice(for: ticker, on: date)
        try cachePrice(ticker: ticker, date: dayStart, price: price)
        return price
    }

    func getHistoricalPrices(for ticker: String, from startDate: Date, to endDate: Date) async throws -> [Date: Double] {
        // For historical ranges, just fetch fresh
        // Could optimize by checking cache first
        let prices = try await wrapped.getHistoricalPrices(for: ticker, from: startDate, to: endDate)

        // Cache all prices
        for (date, price) in prices {
            try? cachePrice(ticker: ticker, date: date, price: price)
        }

        return prices
    }

    private func getCachedPrice(ticker: String, date: Date) throws -> CachedStockPrice? {
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: date)
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart)!

        let predicate = #Predicate<CachedStockPrice> {
            $0.ticker == ticker && $0.date >= dayStart && $0.date < dayEnd
        }

        let descriptor = FetchDescriptor<CachedStockPrice>(predicate: predicate)
        return try modelContext.fetch(descriptor).first
    }

    private func cachePrice(ticker: String, date: Date, price: Double) throws {
        let cached = CachedStockPrice(ticker: ticker, date: date, closePrice: price)
        modelContext.insert(cached)
        try modelContext.save()
    }
}
