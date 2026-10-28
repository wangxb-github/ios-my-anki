import SwiftUI
import AnkiKit

/// 基于 iOS 26 原生 GlassEffectContainer 的极简“红+绿”双键水银分裂评分坞
public struct LiquidMorphingDock: View {
    public let showAnswer: Bool
    public let visibleRatings: [Rating]
    public let nextIntervals: [Rating: String]
    public let showAnswerTitle: String
    public let ratingTitle: ((Rating) -> String)?
    public let onShowAnswer: () -> Void
    public let onRatingSelected: (Rating) -> Void

    @Namespace private var dockNamespace

    /// 始终聚焦于最清晰明了的“红 (Again) + 绿 (Good)”二元评级
    private var twoButtonRatings: [Rating] {
        [.again, .good]
    }

    public init(
        showAnswer: Bool,
        visibleRatings: [Rating] = [.again, .good],
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
        GlassEffectContainer(spacing: 14) {
            if !showAnswer {
                Button {
                    withAnimation(.bouncy(duration: 0.46, extraBounce: 0.14)) {
                        onShowAnswer()
                    }
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 16, weight: .bold))
                        Text(showAnswerTitle)
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 58)
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .glassEffect(Glass.regular.tint(Color.amgiAccent).interactive(), in: .capsule)
                .overlay(
                    Capsule()
                        .strokeBorder(Color.white.opacity(0.28), lineWidth: 1)
                        .allowsHitTesting(false)
                )
                .shadow(color: Color.amgiAccent.opacity(0.35), radius: 12, y: 4)
                .glassEffectID("primary-action", in: dockNamespace)
                .glassEffectTransition(.matchedGeometry)
            } else {
                HStack(spacing: 14) {
                    ForEach(twoButtonRatings, id: \.self) { rating in
                        let isGood = (rating == .good)
                        let tintColor = isGood ? Color.amgiRatingGood : Color.amgiRatingAgain
                        let iconName = isGood ? "checkmark.circle.fill" : "xmark.circle.fill"

                        Button {
                            withAnimation(.bouncy(duration: 0.40, extraBounce: 0.10)) {
                                onRatingSelected(rating)
                            }
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: iconName)
                                    .font(.system(size: 22, weight: .bold))
                                    .foregroundStyle(.white)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(ratingTitle?(rating) ?? defaultRatingTitle(for: rating))
                                        .font(.system(size: 17, weight: .heavy, design: .rounded))
                                    if let interval = nextIntervals[rating], !interval.isEmpty {
                                        Text(interval)
                                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                                            .opacity(0.9)
                                    }
                                }
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 58)
                            .contentShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .glassEffect(Glass.regular.tint(tintColor).interactive(), in: .capsule)
                        .overlay(
                            Capsule()
                                .strokeBorder(Color.white.opacity(0.32), lineWidth: 1.2)
                                .allowsHitTesting(false)
                        )
                        .shadow(color: tintColor.opacity(0.42), radius: 12, y: 4)
                        .glassEffectID("rating-\(rating.rawValue)", in: dockNamespace)
                        .glassEffectTransition(.matchedGeometry)
                    }
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
    }

    private func defaultRatingTitle(for rating: Rating) -> String {
        switch rating {
        case .again: return "重来"
        case .hard: return "困难"
        case .good: return "记住"
        case .easy: return "简单"
        }
    }
}
