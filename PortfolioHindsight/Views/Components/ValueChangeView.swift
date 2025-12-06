import SwiftUI

struct ValueChangeView: View {
    let value: Double
    let percentChange: Double?
    let showArrow: Bool

    init(value: Double, percentChange: Double? = nil, showArrow: Bool = true) {
        self.value = value
        self.percentChange = percentChange
        self.showArrow = showArrow
    }

    private var isPositive: Bool {
        value >= 0
    }

    private var color: Color {
        if value > 0 { return .green }
        if value < 0 { return .red }
        return .secondary
    }

    var body: some View {
        HStack(spacing: 4) {
            if showArrow {
                Image(systemName: value >= 0 ? "arrow.up.right" : "arrow.down.right")
                    .font(.caption)
            }

            Text(formattedValue)

            if let percent = percentChange {
                Text("(\(percent >= 0 ? "+" : "")\(percent, specifier: "%.1f")%)")
                    .font(.caption)
            }
        }
        .foregroundStyle(color)
    }

    private var formattedValue: String {
        let prefix = value > 0 ? "+" : ""
        return prefix + value.formatted(.currency(code: "GBP"))
    }
}

struct LargeValueDisplay: View {
    let label: String
    let value: Double
    let change: Double?
    let changePercent: Double?

    init(label: String, value: Double, change: Double? = nil, changePercent: Double? = nil) {
        self.label = label
        self.value = value
        self.change = change
        self.changePercent = changePercent
    }

    var body: some View {
        VStack(spacing: 8) {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text(value.formatted(.currency(code: "GBP")))
                .font(.system(size: 32, weight: .bold, design: .rounded))

            if let change = change {
                ValueChangeView(
                    value: change,
                    percentChange: changePercent
                )
                .font(.subheadline)
            }
        }
    }
}

struct CompactValueDisplay: View {
    let label: String
    let value: String
    var color: Color = .primary

    var body: some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(color)
        }
    }
}

#Preview {
    VStack(spacing: 24) {
        LargeValueDisplay(
            label: "Portfolio Value",
            value: 12450.00,
            change: 2450.00,
            changePercent: 24.5
        )

        LargeValueDisplay(
            label: "Portfolio Value",
            value: 8500.00,
            change: -1500.00,
            changePercent: -15.0
        )

        HStack {
            CompactValueDisplay(label: "Invested", value: "£10,000")
            CompactValueDisplay(label: "Return", value: "+24.5%", color: .green)
            CompactValueDisplay(label: "Trades", value: "42")
        }

        ValueChangeView(value: 340.50, percentChange: 3.4)
        ValueChangeView(value: -125.00, percentChange: -1.2)
    }
    .padding()
}
