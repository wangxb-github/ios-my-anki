import SwiftUI

/// 卡片正面华丽动态计时器组件（含流光轨道环、色温渐变能量条与连击徽章）
public struct LiquidCardTimerView: View {
    public let startDate: Date
    public let isPaused: Bool
    public let streakCount: Int

    public init(startDate: Date, isPaused: Bool = false, streakCount: Int = 0) {
        self.startDate = startDate
        self.isPaused = isPaused
        self.streakCount = streakCount
    }

    public var body: some View {
        TimelineView(.animation(minimumInterval: 0.05, paused: isPaused)) { context in
            let elapsed = max(0, context.date.timeIntervalSince(startDate))
            timerCapsuleContent(elapsed: elapsed)
        }
    }

    private func timerCapsuleContent(elapsed: TimeInterval) -> some View {
        let phaseColor = Self.phaseColor(for: elapsed)
        let cycleProgress = min(1.0, elapsed / 15.0)

        return HStack(spacing: 10) {
            orbitalRing(progress: cycleProgress, elapsed: elapsed, color: phaseColor)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 5) {
                    Text(Self.formattedTime(elapsed))
                        .font(.system(size: 15, weight: .heavy, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(Color.amgiTextPrimary)

                    Text(Self.phaseLabel(for: elapsed))
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(phaseColor)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1.5)
                        .background(phaseColor.opacity(0.16), in: Capsule())
                }

                energyProgressBar(progress: cycleProgress, color: phaseColor)
            }

            if streakCount >= 2 {
                Divider()
                    .frame(height: 18)
                    .opacity(0.35)

                streakBadge
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .ankiLiquidGlass(minimumCorner: 18)
        .overlay(
            Capsule()
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            phaseColor.opacity(0.55),
                            Color.white.opacity(0.2),
                            phaseColor.opacity(0.35)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.2
                )
        )
        .shadow(color: phaseColor.opacity(0.28), radius: 10, y: 3)
    }

    private func orbitalRing(progress: Double, elapsed: TimeInterval, color: Color) -> some View {
        let angle = elapsed * 120.0
        return ZStack {
            Circle()
                .stroke(color.opacity(0.2), lineWidth: 3)
                .frame(width: 24, height: 24)

            Circle()
                .trim(from: 0, to: CGFloat(max(0.08, progress)))
                .stroke(
                    AngularGradient(
                        colors: [Color.cyan, color, Color.white, color],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 3, lineCap: .round)
                )
                .frame(width: 24, height: 24)
                .rotationEffect(.degrees(-90))

            Circle()
                .fill(Color.white)
                .frame(width: 4.5, height: 4.5)
                .shadow(color: color, radius: 3)
                .offset(y: -12)
                .rotationEffect(.degrees(angle))
        }
    }

    private func energyProgressBar(progress: Double, color: Color) -> some View {
        let totalWidth: CGFloat = 88
        let fillWidth = max(8, totalWidth * CGFloat(progress))
        return ZStack(alignment: .leading) {
            Capsule()
                .fill(Color.secondary.opacity(0.2))
                .frame(width: totalWidth, height: 3.5)

            Capsule()
                .fill(
                    LinearGradient(
                        colors: [Color.cyan, color],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: fillWidth, height: 3.5)
        }
    }

    private var streakBadge: some View {
        HStack(spacing: 3) {
            Image(systemName: "flame.fill")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.orange)
            Text("\(streakCount)")
                .font(.system(size: 13, weight: .black, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(Color.amgiTextPrimary)
        }
    }

    private nonisolated static func phaseColor(for elapsed: TimeInterval) -> Color {
        if elapsed < 6.0 {
            return Color.cyan
        } else if elapsed < 14.0 {
            return Color.amgiRatingGood
        } else if elapsed < 22.0 {
            return Color.amgiRatingHard
        } else {
            return Color.amgiRatingAgain
        }
    }

    private nonisolated static func phaseLabel(for elapsed: TimeInterval) -> String {
        if elapsed < 6.0 {
            return "极速"
        } else if elapsed < 14.0 {
            return "专注"
        } else if elapsed < 22.0 {
            return "深思"
        } else {
            return "超时"
        }
    }

    private nonisolated static func formattedTime(_ elapsed: TimeInterval) -> String {
        let totalTenths = Int(elapsed * 10)
        let tenths = totalTenths % 10
        let totalSeconds = totalTenths / 10
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        if minutes > 0 {
            return String(format: "%d:%02d.%d", minutes, seconds, tenths)
        } else {
            return String(format: "%02d.%ds", seconds, tenths)
        }
    }
}
