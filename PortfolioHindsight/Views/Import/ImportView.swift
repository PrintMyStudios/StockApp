import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct ImportView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var isImporting = false
    @State private var importError: ImportError?
    @State private var showError = false
    @State private var parsedTransactions: [Transaction] = []
    @State private var showPreview = false
    @State private var isProcessing = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                // Icon
                Image(systemName: "doc.text.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(.blue)

                // Title
                VStack(spacing: 8) {
                    Text("Import Transactions")
                        .font(.title2)
                        .fontWeight(.bold)

                    Text("Upload your Freetrade CSV export")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Instructions
                VStack(alignment: .leading, spacing: 16) {
                    InstructionRow(number: 1, text: "Open the Freetrade app")
                    InstructionRow(number: 2, text: "Go to Settings > Activity")
                    InstructionRow(number: 3, text: "Tap 'Export CSV'")
                    InstructionRow(number: 4, text: "Save the file to your device")
                    InstructionRow(number: 5, text: "Tap the button below to import")
                }
                .padding()
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 16))

                Spacer()

                // Import button
                Button {
                    isImporting = true
                } label: {
                    HStack {
                        Image(systemName: "square.and.arrow.down")
                        Text("Select CSV File")
                    }
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.blue)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(isProcessing)

                // Demo data button (for testing)
                Button {
                    loadDemoData()
                } label: {
                    Text("Load Demo Data")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(24)
            .navigationTitle("Import")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .fileImporter(
                isPresented: $isImporting,
                allowedContentTypes: [.commaSeparatedText, .plainText],
                allowsMultipleSelection: false
            ) { result in
                handleFileImport(result)
            }
            .sheet(isPresented: $showPreview) {
                ImportPreviewView(transactions: parsedTransactions) {
                    saveTransactions()
                }
            }
            .alert("Import Error", isPresented: $showError, presenting: importError) { _ in
                Button("OK") { }
            } message: { error in
                Text(error.message)
            }
            .overlay {
                if isProcessing {
                    ProgressView("Processing...")
                        .padding()
                        .background(.regularMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
    }

    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            parseCSVFile(at: url)

        case .failure(let error):
            importError = ImportError(message: error.localizedDescription)
            showError = true
        }
    }

    private func parseCSVFile(at url: URL) {
        isProcessing = true

        Task {
            do {
                // Start accessing the security-scoped resource
                guard url.startAccessingSecurityScopedResource() else {
                    throw ImportError(message: "Cannot access the selected file")
                }
                defer { url.stopAccessingSecurityScopedResource() }

                let csvString = try String(contentsOf: url, encoding: .utf8)
                let transactions = try CSVParserFactory.detectAndParse(csvString)

                await MainActor.run {
                    isProcessing = false
                    parsedTransactions = transactions
                    showPreview = true
                }
            } catch let error as CSVParserError {
                await MainActor.run {
                    isProcessing = false
                    importError = ImportError(message: error.errorDescription ?? "Unknown error")
                    showError = true
                }
            } catch {
                await MainActor.run {
                    isProcessing = false
                    importError = ImportError(message: error.localizedDescription)
                    showError = true
                }
            }
        }
    }

    private func saveTransactions() {
        for transaction in parsedTransactions {
            modelContext.insert(transaction)
        }
        try? modelContext.save()
        dismiss()
    }

    private func loadDemoData() {
        let demoTransactions = generateDemoTransactions()
        parsedTransactions = demoTransactions
        showPreview = true
    }

    private func generateDemoTransactions() -> [Transaction] {
        let calendar = Calendar.current
        let now = Date()

        return [
            Transaction(
                date: calendar.date(byAdding: .month, value: -12, to: now)!,
                type: .buy,
                ticker: "AAPL",
                stockName: "Apple Inc",
                quantity: 10,
                pricePerShare: 145.50,
                totalAmount: 1455.00
            ),
            Transaction(
                date: calendar.date(byAdding: .month, value: -10, to: now)!,
                type: .buy,
                ticker: "MSFT",
                stockName: "Microsoft Corporation",
                quantity: 5,
                pricePerShare: 280.00,
                totalAmount: 1400.00
            ),
            Transaction(
                date: calendar.date(byAdding: .month, value: -8, to: now)!,
                type: .buy,
                ticker: "GOOGL",
                stockName: "Alphabet Inc",
                quantity: 8,
                pricePerShare: 125.00,
                totalAmount: 1000.00
            ),
            Transaction(
                date: calendar.date(byAdding: .month, value: -6, to: now)!,
                type: .sell,
                ticker: "AAPL",
                stockName: "Apple Inc",
                quantity: 5,
                pricePerShare: 160.00,
                totalAmount: 800.00
            ),
            Transaction(
                date: calendar.date(byAdding: .month, value: -5, to: now)!,
                type: .dividend,
                ticker: "MSFT",
                stockName: "Microsoft Corporation",
                quantity: 0,
                pricePerShare: 0,
                totalAmount: 15.50
            ),
            Transaction(
                date: calendar.date(byAdding: .month, value: -4, to: now)!,
                type: .buy,
                ticker: "NVDA",
                stockName: "NVIDIA Corporation",
                quantity: 3,
                pricePerShare: 420.00,
                totalAmount: 1260.00
            ),
            Transaction(
                date: calendar.date(byAdding: .month, value: -2, to: now)!,
                type: .sell,
                ticker: "GOOGL",
                stockName: "Alphabet Inc",
                quantity: 4,
                pricePerShare: 140.00,
                totalAmount: 560.00
            ),
            Transaction(
                date: calendar.date(byAdding: .month, value: -1, to: now)!,
                type: .buy,
                ticker: "TSLA",
                stockName: "Tesla Inc",
                quantity: 6,
                pricePerShare: 245.00,
                totalAmount: 1470.00
            ),
        ]
    }
}

struct InstructionRow: View {
    let number: Int
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Text("\(number)")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundStyle(.white)
                .frame(width: 24, height: 24)
                .background(.blue)
                .clipShape(Circle())

            Text(text)
                .font(.subheadline)
        }
    }
}

struct ImportPreviewView: View {
    let transactions: [Transaction]
    let onConfirm: () -> Void

    @Environment(\.dismiss) private var dismiss

    var summary: (buys: Int, sells: Int, dividends: Int, total: Double) {
        let buys = transactions.filter { $0.type == .buy }.count
        let sells = transactions.filter { $0.type == .sell }.count
        let dividends = transactions.filter { $0.type == .dividend }.count
        let total = transactions.reduce(0) { $0 + $1.totalInBaseCurrency }
        return (buys, sells, dividends, total)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Summary card
                VStack(spacing: 16) {
                    Text("\(transactions.count) Transactions Found")
                        .font(.headline)

                    HStack(spacing: 24) {
                        SummaryItem(label: "Buys", value: "\(summary.buys)", color: .green)
                        SummaryItem(label: "Sells", value: "\(summary.sells)", color: .red)
                        SummaryItem(label: "Dividends", value: "\(summary.dividends)", color: .blue)
                    }
                }
                .padding()
                .background(.regularMaterial)

                // Transactions list
                List(transactions) { transaction in
                    HStack {
                        Image(systemName: transaction.type.icon)
                            .foregroundStyle(colorForType(transaction.type))

                        VStack(alignment: .leading) {
                            Text(transaction.ticker)
                                .font(.headline)
                            Text(transaction.date.formatted(date: .abbreviated, time: .omitted))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Text(transaction.totalInBaseCurrency.formatted(.currency(code: "GBP")))
                            .font(.subheadline)
                    }
                }
                .listStyle(.plain)
            }
            .navigationTitle("Preview Import")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Import") {
                        onConfirm()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }

    private func colorForType(_ type: TransactionType) -> Color {
        switch type {
        case .buy: return .green
        case .sell: return .red
        case .dividend: return .blue
        }
    }
}

struct SummaryItem: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(color)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

struct ImportError: Identifiable {
    let id = UUID()
    let message: String
}

#Preview {
    ImportView()
        .modelContainer(for: Transaction.self, inMemory: true)
}
