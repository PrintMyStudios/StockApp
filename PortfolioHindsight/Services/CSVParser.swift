import Foundation

/// Errors that can occur during CSV parsing
enum CSVParserError: LocalizedError {
    case emptyFile
    case invalidFormat
    case missingRequiredColumn(String)
    case invalidDateFormat(String)
    case invalidNumber(String)
    case unknownTransactionType(String)

    var errorDescription: String? {
        switch self {
        case .emptyFile:
            return "The CSV file is empty"
        case .invalidFormat:
            return "The file format is invalid"
        case .missingRequiredColumn(let column):
            return "Missing required column: \(column)"
        case .invalidDateFormat(let value):
            return "Invalid date format: \(value)"
        case .invalidNumber(let value):
            return "Invalid number: \(value)"
        case .unknownTransactionType(let type):
            return "Unknown transaction type: \(type)"
        }
    }
}

/// Protocol for CSV parsers to support multiple brokers
protocol CSVParserProtocol {
    func parse(_ csvString: String) throws -> [Transaction]
    var supportedBroker: String { get }
}

/// Parser for Freetrade CSV exports
final class FreetradeCVSParser: CSVParserProtocol {
    let supportedBroker = "Freetrade"

    // Expected Freetrade CSV columns
    private enum Column: String, CaseIterable {
        case title = "Title"
        case type = "Type"
        case timestamp = "Timestamp"
        case accountCurrency = "Account Currency"
        case totalAmount = "Total Amount"
        case buyOrSellPrice = "Buy / Sell Price"
        case buyOrSellCurrency = "Buy / Sell Currency"
        case quantity = "Quantity"
        case ticker = "Ticker"
        case fxRate = "FX Rate"
        case baseFxRate = "Base FX Rate"
        case fxFee = "FX Fee"
        case fxFeeAmount = "FX Fee Amount"
        case dividendExDate = "Dividend Ex Date"
        case dividendPayDate = "Dividend Pay Date"
    }

    // Date formatters for Freetrade timestamps
    private lazy var dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()

    private lazy var alternativeDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()

    func parse(_ csvString: String) throws -> [Transaction] {
        let lines = csvString.components(separatedBy: .newlines)
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }

        guard lines.count > 1 else {
            throw CSVParserError.emptyFile
        }

        // Parse header
        let header = parseCSVLine(lines[0])
        let columnIndices = buildColumnIndices(header: header)

        // Validate required columns
        let requiredColumns: [Column] = [.title, .type, .timestamp, .totalAmount, .quantity]
        for column in requiredColumns {
            if columnIndices[column] == nil {
                throw CSVParserError.missingRequiredColumn(column.rawValue)
            }
        }

        // Parse data rows
        var transactions: [Transaction] = []

        for i in 1..<lines.count {
            let values = parseCSVLine(lines[i])

            // Skip empty rows
            guard values.count >= requiredColumns.count else { continue }

            if let transaction = try parseRow(values: values, columnIndices: columnIndices) {
                transactions.append(transaction)
            }
        }

        // Sort by date
        return transactions.sorted { $0.date < $1.date }
    }

    private func parseCSVLine(_ line: String) -> [String] {
        var result: [String] = []
        var current = ""
        var insideQuotes = false

        for char in line {
            if char == "\"" {
                insideQuotes.toggle()
            } else if char == "," && !insideQuotes {
                result.append(current.trimmingCharacters(in: .whitespaces))
                current = ""
            } else {
                current.append(char)
            }
        }
        result.append(current.trimmingCharacters(in: .whitespaces))

        return result
    }

    private func buildColumnIndices(header: [String]) -> [Column: Int] {
        var indices: [Column: Int] = [:]

        for (index, columnName) in header.enumerated() {
            let cleanName = columnName
                .trimmingCharacters(in: .whitespaces)
                .trimmingCharacters(in: CharacterSet(charactersIn: "\""))

            if let column = Column(rawValue: cleanName) {
                indices[column] = index
            }
        }

        return indices
    }

    private func parseRow(values: [String], columnIndices: [Column: Int]) throws -> Transaction? {
        // Get required values
        guard let typeIndex = columnIndices[.type],
              let timestampIndex = columnIndices[.timestamp],
              let titleIndex = columnIndices[.title],
              let totalAmountIndex = columnIndices[.totalAmount],
              let quantityIndex = columnIndices[.quantity],
              values.count > max(typeIndex, timestampIndex, titleIndex, totalAmountIndex, quantityIndex)
        else {
            return nil
        }

        let typeString = getValue(values, at: typeIndex)
        let timestampString = getValue(values, at: timestampIndex)
        let title = getValue(values, at: titleIndex)
        let totalAmountString = getValue(values, at: totalAmountIndex)
        let quantityString = getValue(values, at: quantityIndex)

        // Parse transaction type
        let transactionType = parseTransactionType(typeString)

        // Skip non-trade transactions (like deposits, withdrawals)
        guard let type = transactionType else {
            return nil
        }

        // Parse date
        guard let date = parseDate(timestampString) else {
            throw CSVParserError.invalidDateFormat(timestampString)
        }

        // Parse amounts
        guard let totalAmount = parseNumber(totalAmountString) else {
            throw CSVParserError.invalidNumber(totalAmountString)
        }

        let quantity = parseNumber(quantityString) ?? 0

        // Get optional values
        let ticker = columnIndices[.ticker].flatMap { getValue(values, at: $0) } ?? extractTicker(from: title)
        let pricePerShare = columnIndices[.buyOrSellPrice].flatMap { parseNumber(getValue(values, at: $0)) } ?? (quantity > 0 ? totalAmount / quantity : 0)
        let currency = columnIndices[.buyOrSellCurrency].flatMap { getValue(values, at: $0) } ?? "GBP"
        let fxRate = columnIndices[.fxRate].flatMap { parseNumber(getValue(values, at: $0)) } ?? 1.0

        return Transaction(
            date: date,
            type: type,
            ticker: ticker,
            stockName: title,
            quantity: abs(quantity),
            pricePerShare: abs(pricePerShare),
            totalAmount: abs(totalAmount),
            fees: 0,  // Freetrade is commission-free
            currency: currency,
            fxRate: fxRate
        )
    }

    private func getValue(_ values: [String], at index: Int) -> String {
        guard index < values.count else { return "" }
        return values[index]
            .trimmingCharacters(in: .whitespaces)
            .trimmingCharacters(in: CharacterSet(charactersIn: "\""))
    }

    private func parseTransactionType(_ value: String) -> TransactionType? {
        let lowercased = value.lowercased()

        if lowercased.contains("buy") {
            return .buy
        } else if lowercased.contains("sell") {
            return .sell
        } else if lowercased.contains("dividend") {
            return .dividend
        }

        return nil  // Skip other transaction types
    }

    private func parseDate(_ value: String) -> Date? {
        // Try primary format
        if let date = dateFormatter.date(from: value) {
            return date
        }

        // Try alternative format
        if let date = alternativeDateFormatter.date(from: value) {
            return date
        }

        // Try ISO8601
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = isoFormatter.date(from: value) {
            return date
        }

        isoFormatter.formatOptions = [.withInternetDateTime]
        return isoFormatter.date(from: value)
    }

    private func parseNumber(_ value: String) -> Double? {
        let cleaned = value
            .replacingOccurrences(of: ",", with: "")
            .replacingOccurrences(of: "£", with: "")
            .replacingOccurrences(of: "$", with: "")
            .replacingOccurrences(of: "€", with: "")
            .trimmingCharacters(in: .whitespaces)

        return Double(cleaned)
    }

    private func extractTicker(from title: String) -> String {
        // Try to extract ticker from title like "Apple Inc (AAPL)"
        if let match = title.range(of: #"\(([A-Z0-9]+)\)"#, options: .regularExpression) {
            let tickerWithParens = String(title[match])
            return tickerWithParens
                .replacingOccurrences(of: "(", with: "")
                .replacingOccurrences(of: ")", with: "")
        }

        // Fallback: use first word
        return title.components(separatedBy: " ").first ?? title
    }
}

/// Factory for creating appropriate CSV parser based on file content
struct CSVParserFactory {
    static func detectAndParse(_ csvString: String) throws -> [Transaction] {
        // For now, just use Freetrade parser
        // In future, can detect based on header format
        let parser = FreetradeCVSParser()
        return try parser.parse(csvString)
    }
}
