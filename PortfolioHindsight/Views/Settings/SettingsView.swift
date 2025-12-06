import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var transactions: [Transaction]

    @AppStorage("currencyCode") private var currencyCode = "GBP"
    @AppStorage("defaultTimeRange") private var defaultTimeRange = "all"
    @AppStorage("showDoNothingOnTimeline") private var showDoNothingOnTimeline = false
    @AppStorage("hapticFeedbackEnabled") private var hapticFeedbackEnabled = true

    @State private var showDeleteConfirmation = false
    @State private var showExportSheet = false

    var body: some View {
        NavigationStack {
            List {
                // Portfolio section
                Section {
                    HStack {
                        Label("Transactions", systemImage: "list.bullet")
                        Spacer()
                        Text("\(transactions.count)")
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Label("Holdings", systemImage: "chart.pie")
                        Spacer()
                        Text("\(uniqueTickers.count)")
                            .foregroundStyle(.secondary)
                    }

                    if let firstDate = transactions.min(by: { $0.date < $1.date })?.date {
                        HStack {
                            Label("Tracking Since", systemImage: "calendar")
                            Spacer()
                            Text(firstDate.formatted(date: .abbreviated, time: .omitted))
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("Portfolio")
                }

                // Display section
                Section {
                    Picker("Currency", selection: $currencyCode) {
                        Text("GBP (£)").tag("GBP")
                        Text("USD ($)").tag("USD")
                        Text("EUR (€)").tag("EUR")
                    }

                    Picker("Default Time Range", selection: $defaultTimeRange) {
                        Text("1 Week").tag("week")
                        Text("1 Month").tag("month")
                        Text("3 Months").tag("threeMonths")
                        Text("1 Year").tag("year")
                        Text("All Time").tag("all")
                    }

                    Toggle("Show Buy & Hold on Timeline", isOn: $showDoNothingOnTimeline)
                } header: {
                    Text("Display")
                } footer: {
                    Text("Show the comparison line on the timeline chart by default")
                }

                // App section
                Section {
                    Toggle("Haptic Feedback", isOn: $hapticFeedbackEnabled)
                } header: {
                    Text("App")
                }

                // Data section
                Section {
                    NavigationLink {
                        ImportView()
                    } label: {
                        Label("Import Transactions", systemImage: "square.and.arrow.down")
                    }

                    Button {
                        showExportSheet = true
                    } label: {
                        Label("Export Data", systemImage: "square.and.arrow.up")
                    }

                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        Label("Delete All Data", systemImage: "trash")
                    }
                } header: {
                    Text("Data")
                }

                // About section
                Section {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundStyle(.secondary)
                    }

                    Link(destination: URL(string: "https://github.com/portfolio-hindsight")!) {
                        HStack {
                            Text("GitHub")
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .foregroundStyle(.secondary)
                        }
                    }

                    Link(destination: URL(string: "mailto:support@portfoliohindsight.app")!) {
                        HStack {
                            Text("Send Feedback")
                            Spacer()
                            Image(systemName: "envelope")
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("About")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .alert("Delete All Data?", isPresented: $showDeleteConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    deleteAllData()
                }
            } message: {
                Text("This will permanently delete all your transactions and cannot be undone.")
            }
            .sheet(isPresented: $showExportSheet) {
                ExportView(transactions: Array(transactions))
            }
        }
    }

    private var uniqueTickers: Set<String> {
        Set(transactions.map { $0.ticker })
    }

    private func deleteAllData() {
        for transaction in transactions {
            modelContext.delete(transaction)
        }
        try? modelContext.save()
    }
}

struct ExportView: View {
    let transactions: [Transaction]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 60))
                    .foregroundStyle(.blue)

                Text("Export Your Data")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("Export \(transactions.count) transactions as a CSV file")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Spacer()

                if let csvData = generateCSV().data(using: .utf8) {
                    ShareLink(
                        item: csvData,
                        preview: SharePreview("Portfolio Hindsight Export", icon: "doc.text")
                    ) {
                        HStack {
                            Image(systemName: "square.and.arrow.up")
                            Text("Export CSV")
                        }
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.blue)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
            .padding(24)
            .navigationTitle("Export")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func generateCSV() -> String {
        var csv = "Date,Type,Ticker,Stock Name,Quantity,Price,Total,Currency\n"

        let formatter = ISO8601DateFormatter()

        for transaction in transactions.sorted(by: { $0.date < $1.date }) {
            let row = [
                formatter.string(from: transaction.date),
                transaction.type.rawValue,
                transaction.ticker,
                "\"\(transaction.stockName)\"",
                String(format: "%.4f", transaction.quantity),
                String(format: "%.2f", transaction.pricePerShare),
                String(format: "%.2f", transaction.totalAmount),
                transaction.currency
            ].joined(separator: ",")

            csv += row + "\n"
        }

        return csv
    }
}

#Preview {
    SettingsView()
        .modelContainer(for: Transaction.self, inMemory: true)
}
