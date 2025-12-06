import Foundation

extension Double {
    /// Format as currency with sign
    func formattedAsCurrency(code: String = "GBP", showSign: Bool = false) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = code

        if showSign && self > 0 {
            return "+\(formatter.string(from: NSNumber(value: self)) ?? "\(self)")"
        }
        return formatter.string(from: NSNumber(value: self)) ?? "\(self)"
    }

    /// Format as percentage
    func formattedAsPercent(decimals: Int = 1, showSign: Bool = true) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = decimals
        formatter.maximumFractionDigits = decimals

        let formatted = formatter.string(from: NSNumber(value: self)) ?? "\(self)"

        if showSign && self > 0 {
            return "+\(formatted)%"
        }
        return "\(formatted)%"
    }

    /// Format as compact number (1.2K, 1.5M, etc.)
    func formattedCompact() -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal

        if abs(self) >= 1_000_000 {
            formatter.maximumFractionDigits = 1
            return "\(formatter.string(from: NSNumber(value: self / 1_000_000)) ?? "")M"
        } else if abs(self) >= 1_000 {
            formatter.maximumFractionDigits = 1
            return "\(formatter.string(from: NSNumber(value: self / 1_000)) ?? "")K"
        } else {
            formatter.maximumFractionDigits = 0
            return formatter.string(from: NSNumber(value: self)) ?? "\(self)"
        }
    }
}

extension Int {
    /// Format with thousands separator
    func formattedWithSeparator() -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: self)) ?? "\(self)"
    }
}
