import SwiftUI

struct ScoreRingView: View {
    let score: Int
    let rating: TradingRating
    let size: CGFloat

    init(score: Int, rating: TradingRating, size: CGFloat = 80) {
        self.score = score
        self.rating = rating
        self.size = size
    }

    private var progress: Double {
        Double(score) / 100.0
    }

    private var ringColor: Color {
        switch rating {
        case .excellent: return .green
        case .good: return .green
        case .neutral: return .yellow
        case .poor: return .orange
        case .veryPoor: return .red
        }
    }

    var body: some View {
        ZStack {
            // Background ring
            Circle()
                .stroke(ringColor.opacity(0.2), lineWidth: size * 0.1)

            // Progress ring
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    ringColor,
                    style: StrokeStyle(
                        lineWidth: size * 0.1,
                        lineCap: .round
                    )
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeOut(duration: 0.8), value: score)

            // Score text
            VStack(spacing: 0) {
                Text("\(score)")
                    .font(.system(size: size * 0.3, weight: .bold, design: .rounded))
                Text("score")
                    .font(.system(size: size * 0.12))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: size, height: size)
    }
}

struct TradingScoreBadge: View {
    let score: TradingScore

    var body: some View {
        HStack(spacing: 12) {
            ScoreRingView(score: score.score, rating: score.rating, size: 60)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Image(systemName: score.rating.icon)
                    Text(ratingText)
                }
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(ratingColor)

                Text(score.message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer()
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var ratingText: String {
        switch score.rating {
        case .excellent: return "Excellent"
        case .good: return "Good"
        case .neutral: return "Neutral"
        case .poor: return "Needs Work"
        case .veryPoor: return "Poor"
        }
    }

    private var ratingColor: Color {
        switch score.rating {
        case .excellent, .good: return .green
        case .neutral: return .yellow
        case .poor, .veryPoor: return .red
        }
    }
}

#Preview {
    VStack(spacing: 24) {
        HStack(spacing: 24) {
            ScoreRingView(score: 85, rating: .excellent)
            ScoreRingView(score: 65, rating: .good)
            ScoreRingView(score: 50, rating: .neutral)
            ScoreRingView(score: 25, rating: .poor)
        }

        TradingScoreBadge(score: TradingScore(
            score: 72,
            rating: .good,
            message: "Your trading is adding value compared to buy-and-hold"
        ))

        TradingScoreBadge(score: TradingScore(
            score: 35,
            rating: .poor,
            message: "Buy-and-hold would be outperforming your active trading"
        ))
    }
    .padding()
}
