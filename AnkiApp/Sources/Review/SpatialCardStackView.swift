import SwiftUI
import AnkiKit

/// 华丽答题光效与粒子迸发层（独立 sibling overlay，不触碰 WKWebView 渲染树）
public struct AnswerBurstEffectView: View {
    public let rating: Rating
    public let progress: CGFloat

    public init(rating: Rating, progress: CGFloat) {
        self.rating = rating
        self.progress = progress
    }

    private var primaryColor: Color {
        rating == .again ? Color.amgiRatingAgain : Color.amgiRatingGood
    }

    private var secondaryColor: Color {
        rating == .again ? Color.orange : Color.cyan
    }

    public var body: some View {
        GeometryReader { geo in
            let center = CGPoint(x: geo.size.width * 0.5, y: geo.size.height * 0.46)
            let maxRadius = min(geo.size.width, geo.size.height) * 0.72
            let fade = Double(max(0, 1.0 - progress))

            ZStack {
                // 全屏边缘极光脉冲辉光
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                primaryColor.opacity(fade * 0.9),
                                secondaryColor.opacity(fade * 0.65),
                                primaryColor.opacity(fade * 0.9)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: CGFloat(max(2, (1.0 - progress) * 10))
                    )
                    .padding(6)

                // 外圈扩散能量冲击波
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [primaryColor.opacity(fade * 0.95), secondaryColor.opacity(fade * 0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: CGFloat(max(1.5, (1.0 - progress) * 8))
                    )
                    .frame(
                        width: max(20, maxRadius * 1.45 * progress),
                        height: max(20, maxRadius * 1.45 * progress)
                    )
                    .position(center)

                // 内圈高频能量环
                Circle()
                    .stroke(secondaryColor.opacity(fade * 0.8), lineWidth: CGFloat(max(1, (1.0 - progress) * 4)))
                    .frame(
                        width: max(12, maxRadius * 0.95 * progress),
                        height: max(12, maxRadius * 0.95 * progress)
                    )
                    .position(center)

                // 16 颗发散星芒粒子
                ForEach(0..<16, id: \.self) { index in
                    let angle = Double(index) * (.pi * 2.0 / 16.0) + Double(progress) * 0.35
                    let radius = Double(maxRadius) * (0.18 + Double(progress) * (index.isMultiple(of: 2) ? 0.78 : 0.55))
                    let px = center.x + CGFloat(cos(angle) * radius)
                    let py = center.y + CGFloat(sin(angle) * radius)
                    let pScale = max(0.1, 1.15 - progress * 0.9)

                    Image(systemName: index.isMultiple(of: 2) ? "sparkle" : "circle.fill")
                        .font(.system(size: index.isMultiple(of: 2) ? 18 : 8, weight: .bold))
                        .foregroundStyle(index.isMultiple(of: 2) ? primaryColor : secondaryColor)
                        .scaleEffect(pScale)
                        .opacity(fade)
                        .position(x: px, y: py)
                }

                // 中心悬浮液态徽章
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [primaryColor.opacity(0.92), primaryColor.opacity(0.35)],
                                center: .center,
                                startRadius: 4,
                                endRadius: 44
                            )
                        )
                        .frame(width: 78, height: 78)

                    Image(systemName: rating == .again ? "arrow.counterclockwise" : "checkmark")
                        .font(.system(size: 34, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                }
                .scaleEffect(progress < 0.25 ? (0.5 + progress * 2.4) : (1.1 - (progress - 0.25) * 0.35))
                .opacity(fade)
                .position(center)
            }
        }
        .allowsHitTesting(false)
    }
}

/// 具备水平阻尼滑动评分、翻牌流光扫光与华丽粒子反馈的闪卡容器（零 Metal offscreen 栅格化，100% 兼容 WKWebView）
public struct SpatialCardStackView<Content: View>: View {
    public let showAnswer: Bool
    public let allowsTapToFlip: Bool
    public let allowsVerticalRatingSwipe: Bool
    public let showsBackgroundStack: Bool
    public let externalBurstTrigger: Int
    public let externalBurstRating: Rating
    public let onFlip: () -> Void
    public let onRating: (Rating) -> Void
    @ViewBuilder public let content: () -> Content

    @State private var dragOffset: CGSize = .zero
    @State private var flipScale: CGFloat = 1.0
    @State private var shimmerPhase: CGFloat = -1.2
    @State private var showShimmer: Bool = false
    @State private var rippleTime: Float = 0.0
    @State private var rippleOrigin: CGPoint = CGPoint(x: 180, y: 220)
    @State private var activeRatingHint: Rating? = nil
    @State private var burstProgress: CGFloat = 0.0
    @State private var isBursting: Bool = false
    @State private var currentBurstRating: Rating = .good

    private let horizontalThreshold: CGFloat = 105.0
    private let flipSwipeThreshold: CGFloat = 85.0

    public init(
        showAnswer: Bool,
        allowsTapToFlip: Bool = false,
        allowsVerticalRatingSwipe: Bool = false,
        showsBackgroundStack: Bool = false,
        externalBurstTrigger: Int = 0,
        externalBurstRating: Rating = .good,
        onFlip: @escaping () -> Void,
        onRating: @escaping (Rating) -> Void,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.showAnswer = showAnswer
        self.allowsTapToFlip = allowsTapToFlip
        self.allowsVerticalRatingSwipe = allowsVerticalRatingSwipe
        self.showsBackgroundStack = showsBackgroundStack
        self.externalBurstTrigger = externalBurstTrigger
        self.externalBurstRating = externalBurstRating
        self.onFlip = onFlip
        self.onRating = onRating
        self.content = content
    }

    public var body: some View {
        GeometryReader { geo in
            ZStack {
                if showsBackgroundStack {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(Color.amgiSurface.opacity(0.45))
                        .ankiLiquidGlass(minimumCorner: 24)
                        .scaleEffect(0.91)
                        .offset(y: 22)
                        .opacity(0.65)

                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(Color.amgiSurface.opacity(0.65))
                        .ankiLiquidGlass(minimumCorner: 24)
                        .scaleEffect(0.96)
                        .offset(y: 11)
                        .opacity(0.85)
                }

                // 前景主卡片（仅使用纯 2D 仿射变换，绝不触发 WKWebView Metal offscreen 黄色报错框）
                content()
                    .scaleEffect(flipScale)
                    .offset(dragOffset)
                    .rotationEffect(.degrees(Double(dragOffset.width) / 38.0))
                    .overlay {
                        // 滑动方向状态发光提示边缘（左红 Again / 右绿 Good）
                        if showAnswer, let hint = activeRatingHint {
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .strokeBorder(ratingRimColor(for: hint), lineWidth: 4.0)
                                .padding(4)
                                .opacity(0.92)
                                .allowsHitTesting(false)
                        }
                    }
                    .overlay {
                        // 揭晓答案时的全息流光扫过特效
                        if showShimmer {
                            LinearGradient(
                                colors: [
                                    .clear,
                                    Color.cyan.opacity(0.22),
                                    Color.white.opacity(0.38),
                                    Color.purple.opacity(0.20),
                                    .clear
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                            .frame(width: geo.size.width * 0.65)
                            .offset(x: shimmerPhase * geo.size.width)
                            .allowsHitTesting(false)
                        }
                    }
                    .ankiCausticRipple(origin: rippleOrigin, time: rippleTime, amplitude: 0.75)
                    .overlay {
                        if isBursting {
                            AnswerBurstEffectView(rating: currentBurstRating, progress: burstProgress)
                        }
                    }
                    .simultaneousGesture(
                        DragGesture(minimumDistance: 28)
                            .onChanged { value in
                                let dx = value.translation.width
                                let dy = value.translation.height
                                let isHorizontalDominant = abs(dx) > abs(dy) * 1.35

                                guard isHorizontalDominant else {
                                    if dragOffset != .zero {
                                        dragOffset = .zero
                                        activeRatingHint = nil
                                    }
                                    return
                                }

                                if showAnswer {
                                    dragOffset = CGSize(width: dx, height: dy * 0.15)
                                    updateRatingHint()
                                } else {
                                    dragOffset = CGSize(width: dx * 0.45, height: 0)
                                }
                            }
                            .onEnded { value in
                                handleDragEnded(translation: value.translation, cardSize: geo.size)
                            }
                    )
                    .onTapGesture { point in
                        guard allowsTapToFlip else { return }
                        rippleOrigin = point
                        onFlip()
                    }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, showsBackgroundStack ? 16 : 0)
            .padding(.vertical, showsBackgroundStack ? 8 : 0)
            .onChange(of: showAnswer) { _, isShowingAnswer in
                if isShowingAnswer {
                    let center = CGPoint(x: geo.size.width * 0.5, y: geo.size.height * 0.5)
                    triggerFlipAnimation(at: center)
                } else {
                    var transaction = Transaction()
                    transaction.disablesAnimations = true
                    withTransaction(transaction) {
                        flipScale = 1.0
                        rippleTime = 0.0
                        showShimmer = false
                        activeRatingHint = nil
                    }
                }
            }
            .onChange(of: externalBurstTrigger) { _, newValue in
                guard newValue > 0 else { return }
                playBurstAnimation(for: externalBurstRating)
            }
        }
    }

    private func triggerFlipAnimation(at origin: CGPoint) {
        rippleOrigin = origin
        var snap = Transaction()
        snap.disablesAnimations = true
        withTransaction(snap) {
            flipScale = 0.965
            rippleTime = 0.02
            shimmerPhase = -0.9
            showShimmer = true
        }

        HapticSymphony.shared.playFlipRatchet()

        withAnimation(.spring(response: 0.36, dampingFraction: 0.72)) {
            flipScale = 1.0
        }
        withAnimation(.easeOut(duration: 0.48)) {
            rippleTime = 1.0
            shimmerPhase = 1.15
        }

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 500_000_000)
            var reset = Transaction()
            reset.disablesAnimations = true
            withTransaction(reset) {
                rippleTime = 0.0
                showShimmer = false
            }
        }
    }

    private func playBurstAnimation(for rating: Rating) {
        currentBurstRating = rating
        var snap = Transaction()
        snap.disablesAnimations = true
        withTransaction(snap) {
            burstProgress = 0.02
            isBursting = true
        }

        withAnimation(.easeOut(duration: 0.42)) {
            burstProgress = 1.0
        }

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 430_000_000)
            var reset = Transaction()
            reset.disablesAnimations = true
            withTransaction(reset) {
                isBursting = false
                burstProgress = 0.0
            }
        }
    }

    private func updateRatingHint() {
        guard showAnswer else {
            activeRatingHint = nil
            return
        }

        let newHint: Rating?
        if dragOffset.width < -horizontalThreshold {
            newHint = .again
        } else if dragOffset.width > horizontalThreshold {
            newHint = .good
        } else {
            newHint = nil
        }

        if newHint != activeRatingHint {
            if let rating = newHint {
                HapticSymphony.shared.playThresholdSnap(for: rating)
            }
            activeRatingHint = newHint
        }
    }

    private func handleDragEnded(translation: CGSize, cardSize: CGSize) {
        let isHorizontalDominant = abs(translation.width) > abs(translation.height) * 1.35
        guard isHorizontalDominant else {
            if dragOffset != .zero {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.78)) {
                    dragOffset = .zero
                    activeRatingHint = nil
                }
            }
            return
        }

        guard showAnswer else {
            withAnimation(.spring(response: 0.38, dampingFraction: 0.75)) {
                dragOffset = .zero
                activeRatingHint = nil
            }
            if abs(translation.width) > flipSwipeThreshold {
                onFlip()
            }
            return
        }

        if translation.width < -horizontalThreshold {
            // 左滑 -> 红色 Again
            commitSwipeRating(.again, exitOffset: CGSize(width: -max(420, cardSize.width * 1.1), height: 0))
        } else if translation.width > horizontalThreshold {
            // 右滑 -> 绿色 Good
            commitSwipeRating(.good, exitOffset: CGSize(width: max(420, cardSize.width * 1.1), height: 0))
        } else {
            withAnimation(.spring(response: 0.42, dampingFraction: 0.75)) {
                dragOffset = .zero
                activeRatingHint = nil
            }
        }
    }

    private func commitSwipeRating(_ rating: Rating, exitOffset: CGSize) {
        playBurstAnimation(for: rating)
        withAnimation(.easeIn(duration: 0.18)) {
            dragOffset = exitOffset
        }
        HapticSymphony.shared.playThresholdSnap(for: rating)
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 190_000_000)
            var reset = Transaction()
            reset.disablesAnimations = true
            withTransaction(reset) {
                dragOffset = .zero
                activeRatingHint = nil
                flipScale = 1.0
            }
            onRating(rating)
        }
    }

    private func ratingRimColor(for rating: Rating) -> Color {
        switch rating {
        case .again: return Color.amgiRatingAgain
        case .hard: return Color.amgiRatingHard
        case .good: return Color.amgiRatingGood
        case .easy: return Color.amgiRatingEasy
        }
    }
}
