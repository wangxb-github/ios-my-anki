import SwiftUI

/// 沉浸式无干扰流光计时器（顶部 2.5pt 极光呼吸流光线 + 微缩静谧胶囊，不抢夺卡片正文视觉焦点）
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
        TimelineView(.animation(minimumInterval: 0.1, paused: isPaused)) { context in
            let elapsed = max(0, context.date.timeIntervalSince(startDate))
            ambientTimerHeader(elapsed: elapsed)
        }
        .allowsHitTesting(false)
    }

    private func ambientTimerHeader(elapsed: TimeInterval) -> some View {
        let phaseColor = Self.phaseColor(for: elapsed)
        let cycleProgress = min(1.0, elapsed / 20.0)

        return VStack(spacing: 6) {
            ambientRibbonBar(progress: cycleProgress, color: phaseColor)

            HStack {
                Spacer()
                microStatusPill(elapsed: elapsed, color: phaseColor)
            }
            .padding(.horizontal, 14)
        }
    }

    /// 顶部 2.5pt 极细流光进度丝带（余光即可感知时间流逝，无需注视）
    private func ambientRibbonBar(progress: Double, color: Color) -> some View {
        GeometryReader { geo in
            let totalWidth = geo.size.width
            let activeWidth = max(12, totalWidth * CGFloat(progress))

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.primary.opacity(0.06))
                    .frame(height: 2.5)

                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.amgiAccent.opacity(0.25),
                                color.opacity(0.65),
                                color.opacity(0.9)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: activeWidth, height: 2.5)

                // 前端柔和呼吸光珠
                Circle()
                    .fill(color)
                    .frame(width: 5, height: 5)
                    .shadow(color: color.opacity(0.8), radius: 4)
                    .offset(x: max(0, activeWidth - 4))
            }
        }
        .frame(height: 5)
        .padding(.horizontal, 16)
    }

    /// 右上角微缩半透明静谧胶囊（仅按整秒柔和过渡，去除高频毫秒跳动干扰）
    private func microStatusPill(elapsed: TimeInterval, color: Color) -> some View {
        let wholeSeconds = Int(elapsed)
        let pulseOpacity = 0.55 + 0.35 * sin(elapsed * 2.2)

        return HStack(spacing: 5) {
            Circle()
                .fill(color.opacity(pulseOpacity))
                .frame(width: 5.5, height: 5.5)

            Text(Self.formattedWholeSeconds(wholeSeconds))
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(Color.amgiTextSecondary)
                .contentTransition(.numericText())

            if streakCount >= 3 {
                Text("·")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Color.amgiTextTertiary)

                HStack(spacing: 2) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.orange.opacity(0.85))
                    Text("\(streakCount)")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(Color.amgiTextSecondary)
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3.5)
        .background(Color.amgiSurface.opacity(0.55), in: Capsule())
        .overlay(
            Capsule()
                .strokeBorder(color.opacity(0.22), lineWidth: 0.8)
        )
        .opacity(0.76)
    }

    private nonisolated static func phaseColor(for elapsed: TimeInterval) -> Color {
        if elapsed < 8.0 {
            return Color.cyan
        } else if elapsed < 16.0 {
            return Color.amgiRatingGood
        } else if elapsed < 25.0 {
            return Color.amgiRatingHard
        } else {
            return Color.amgiRatingAgain
        }
    }

    private nonisolated static func formattedWholeSeconds(_ totalSeconds: Int) -> String {
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        if minutes > 0 {
            return String(format: "%d:%02d", minutes, seconds)
        } else {
            return String(format: "%ds", seconds)
        }
    }
}
