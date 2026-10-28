import SwiftUI
import AnkiKit

struct DeckCountsView: View {
    let counts: DeckCounts

    var body: some View {
        HStack(spacing: 6) {
            if counts.newCount > 0 {
                countBadge(counts.newCount, color: .amgiAccent)
            }
            if counts.learnCount > 0 {
                countBadge(counts.learnCount, color: .amgiRatingHard)
            }
            if counts.reviewCount > 0 {
                countBadge(counts.reviewCount, color: .amgiRatingGood)
            }
            if counts.total == 0 {
                completedBadge
            }
        }
    }

    private func countBadge(_ count: Int, color: Color) -> some View {
        Text("\(count)")
            .font(.system(size: 12, weight: .bold, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.16), in: Capsule())
            .overlay(
                Capsule()
                    .strokeBorder(color.opacity(0.38), lineWidth: 1)
            )
    }

    private var completedBadge: some View {
        HStack(spacing: 3) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Color.amgiRatingGood)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(Color.amgiRatingGood.opacity(0.14), in: Capsule())
    }
}
