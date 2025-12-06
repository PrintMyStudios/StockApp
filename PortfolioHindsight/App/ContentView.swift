import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var transactions: [Transaction]

    var body: some View {
        Group {
            if transactions.isEmpty {
                OnboardingView()
            } else {
                MainTabView()
            }
        }
    }
}

struct OnboardingView: View {
    @State private var showImport = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                Spacer()

                VStack(spacing: 16) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 80))
                        .foregroundStyle(.blue)

                    Text("Portfolio Hindsight")
                        .font(.largeTitle)
                        .fontWeight(.bold)

                    Text("See if your trading decisions are\nhelping or hurting your returns")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                Spacer()

                VStack(spacing: 16) {
                    FeatureRow(
                        icon: "doc.text",
                        title: "Import Your Trades",
                        description: "Upload your Freetrade CSV export"
                    )

                    FeatureRow(
                        icon: "chart.xyaxis.line",
                        title: "Track Over Time",
                        description: "See your portfolio at any point in history"
                    )

                    FeatureRow(
                        icon: "arrow.left.arrow.right",
                        title: "Compare Strategies",
                        description: "What if you'd just left it alone?"
                    )
                }
                .padding(.horizontal, 24)

                Spacer()

                Button {
                    showImport = true
                } label: {
                    Text("Get Started")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.blue)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
            .sheet(isPresented: $showImport) {
                ImportView()
            }
        }
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.blue)
                .frame(width: 44, height: 44)
                .background(.blue.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
    }
}

struct MainTabView: View {
    @State private var selectedTab = 0
    @State private var showSettings = false

    var body: some View {
        TabView(selection: $selectedTab) {
            DashboardView()
                .tabItem {
                    Label("Dashboard", systemImage: "square.grid.2x2")
                }
                .tag(0)

            TimelineView()
                .tabItem {
                    Label("Timeline", systemImage: "chart.xyaxis.line")
                }
                .tag(1)

            CompareView()
                .tabItem {
                    Label("Compare", systemImage: "arrow.left.arrow.right")
                }
                .tag(2)

            TradesListView()
                .tabItem {
                    Label("Trades", systemImage: "list.bullet")
                }
                .tag(3)

            SettingsTabView(showSettings: $showSettings)
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
                .tag(4)
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
    }
}

struct SettingsTabView: View {
    @Binding var showSettings: Bool

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        showSettings = true
                    } label: {
                        Label("Open Settings", systemImage: "gearshape")
                    }
                }
            }
            .navigationTitle("Settings")
            .onAppear {
                showSettings = true
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Transaction.self, inMemory: true)
}
