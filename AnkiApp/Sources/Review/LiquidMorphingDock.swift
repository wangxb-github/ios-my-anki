import SwiftUI
import AnkiKit

/// 基于 iOS 26 原生 GlassEffectContainer 的水银分裂/合拢评分坞 (Liquid Morphing Dock)
public struct LiquidMorphingDock: View {
    public let showAnswer: Bool
    public let visibleRatings: [Rating]
    public let nextIntervals: [Rating: String]
    public let showAnswerTitle: String
    public let ratingTitle: ((Rating) -> String)?
    public let onShowAnswer: () -> Void
    public let onRatingSelected: (Rating) -> Void

    @Namespace private var dockNamespace

    public init(
        showAnswer: Bool,
        visibleRatings: [Rating],
        nextIntervals: [Rating: String],
        showAnswerTitle: String = "Show Answer",
        ratingTitle: ((Rating) -> String)? = nil,
        onShowAnswer: @escaping () -> Void,
        onRatingSelected: @escaping (Rating) -> Void
    ) {
        self.showAnswer = showAnswer
        self.visibleRatings = visibleRatings
        self.nextIntervals = nextIntervals
        self.showAnswerTitle = showAnswerTitle
        self.ratingTitle = ratingTitle
        self.onShowAnswer = onShowAnswer
        self.onRatingSelected = onRatingSelected
    }

    public var body: some View {
        GlassEffectContainer(spacing: 10) {
            if !showAnswer {
                Button {
                    withAnimation(.bouncy(duration: 0.45, extraBounce: 0.12)) {
                        onShowAnswer()
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "eye.fill")
                            .font(.system(size: 15, weight: .semibold))
                        Text(showAnswerTitle)
                            .font(.system(size: 17, weight: .semibold, design: .rounded))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .glassEffect(Glass.regular.tint(Color.amgiAccent).interactive(), in: .capsule)
                .glassEffectID("primary-action", in: dockNamespace)
                .glassEffectTransition(.matchedGeometry)
            } else {
                HStack(spacing: 8) {
                    ForEach(visibleRatings, id: \.self) { rating in
                        Button {
                            withAnimation(.bouncy(duration: 0.38, extraBounce: 0.08)) {
                                onRatingSelected(rating)
                            }
                        } label: {
                            VStack(spacing: 2) {
                                if let interval = nextIntervals[rating], !interval.isEmpty {
                                    Text(interval)
                                        .font(.system(size: 11, weight: .medium, design: .rounded))
                                        .opacity(0.85)
                                }
                                Text(ratingTitle?(rating) ?? defaultRatingTitle(for: rating))
                                    .font(.system(size: 15, weight: .bold, design: .rounded))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .contentShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .glassEffect(Glass.regular.tint(ratingLiquidColor(for: rating)).interactive(), in: .capsule)
                        .glassEffectID("rating-\(rating.rawValue)", in: dockNamespace)
                        .glassEffectTransition(.matchedGeometry)
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    private func defaultRatingTitle(for rating: Rating) -> String {
        switch rating {
        case .again: return "Again"
        case .hard: return "Hard"
        case .good: return "Good"
        case .easy: return "Easy"
        }
    }

    private func ratingLiquidColor(for rating: Rating) -> Color {
        switch rating {
        case .again: return Color.amgiRatingAgain
        case .hard: return Color.amgiRatingHard
        case .good: return Color.amgiRatingGood
        case .easy: return Color.amgiRatingEasy
        }
    }
}
