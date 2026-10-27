import SwiftUI
import AnkiKit

/// 120Hz 3D 物理姿态动画修饰器（显式实现 Animatable 协议，兼容无 SwiftUIMacros 插件的轻量 CommandLineTools / Playgrounds 环境）
struct CardSpatialPoseModifier: ViewModifier, Animatable {
    var dragOffset: CGSize
    var flipDegrees: Double
    var dissolveProgress: Float
    var rippleTime: Float
    var rippleOrigin: CGPoint = .zero

    nonisolated var animatableData: AnimatablePair<
        CGSize.AnimatableData,
        AnimatablePair<Double, AnimatablePair<Float, Float>>
    > {
        get {
            AnimatablePair(
                dragOffset.animatableData,
                AnimatablePair(
                    flipDegrees,
                    AnimatablePair(dissolveProgress, rippleTime)
                )
            )
        }
        set {
            dragOffset.animatableData = newValue.first
            flipDegrees = newValue.second.first
            dissolveProgress = newValue.second.second.first
            rippleTime = newValue.second.second.second
        }
    }

    func body(content: Content) -> some View {
        let rotY = Double(dragOffset.width) / 18.0
        let rotX = -Double(dragOffset.height) / 26.0

        content
            .offset(dragOffset)
            .rotation3DEffect(.degrees(rotY), axis: (x: 0, y: 1, z: 0), perspective: 0.5)
            .rotation3DEffect(.degrees(rotX), axis: (x: 1, y: 0, z: 0), perspective: 0.5)
            .rotation3DEffect(.degrees(flipDegrees), axis: (x: 0, y: 1, z: 0), perspective: 0.55)
            .ankiCausticRipple(origin: rippleOrigin, time: rippleTime, amplitude: 0.65)
    }
}

/// 具备 3D 物理手势、水平阻尼滑动评分与域扭曲斩杀特效的闪卡容器
public struct SpatialCardStackView<Content: View>: View {
    public let showAnswer: Bool
    public let allowsTapToFlip: Bool
    public let allowsVerticalRatingSwipe: Bool
    public let showsBackgroundStack: Bool
    public let onFlip: () -> Void
    public let onRating: (Rating) -> Void
    @ViewBuilder public let content: () -> Content

    @State private var dragOffset: CGSize = .zero
    @State private var flipDegrees: Double = 0.0
    @State private var dissolveProgress: Float = 0.0
    @State private var rippleTime: Float = 0.0
    @State private var rippleOrigin: CGPoint = CGPoint(x: 180, y: 220)
    @State private var activeRatingHint: Rating? = nil

    private let horizontalThreshold: CGFloat = 110.0
    private let verticalThreshold: CGFloat = 125.0
    private let flipSwipeThreshold: CGFloat = 85.0

    public init(
        showAnswer: Bool,
        allowsTapToFlip: Bool = false,
        allowsVerticalRatingSwipe: Bool = false,
        showsBackgroundStack: Bool = false,
        onFlip: @escaping () -> Void,
        onRating: @escaping (Rating) -> Void,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.showAnswer = showAnswer
        self.allowsTapToFlip = allowsTapToFlip
        self.allowsVerticalRatingSwipe = allowsVerticalRatingSwipe
        self.showsBackgroundStack = showsBackgroundStack
        self.onFlip = onFlip
        self.onRating = onRating
        self.content = content
    }

    public var body: some View {
        GeometryReader { geo in
            ZStack {
                if showsBackgroundStack {
                    // 背景景深卡片 2（更深）
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(Color.amgiSurface.opacity(0.45))
                        .ankiLiquidGlass(minimumCorner: 24)
                        .scaleEffect(0.91)
                        .offset(y: 22)
                        .opacity(0.65)

                    // 背景景深卡片 1（稍浅）
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(Color.amgiSurface.opacity(0.65))
                        .ankiLiquidGlass(minimumCorner: 24)
                        .scaleEffect(0.96)
                        .offset(y: 11)
                        .opacity(0.85)
                }

                // 前景主卡片
                ZStack {
                    content()

                    // 滑动方向状态发光提示边缘（仅在已揭晓答案态显示评级色散）
                    if showAnswer, let hint = activeRatingHint {
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(ratingRimColor(for: hint), lineWidth: 3.5)
                            .opacity(0.88)
                            .allowsHitTesting(false)
                    }
                }
                .modifier(
                    CardSpatialPoseModifier(
                        dragOffset: dragOffset,
                        flipDegrees: flipDegrees,
                        dissolveProgress: dissolveProgress,
                        rippleTime: rippleTime,
                        rippleOrigin: rippleOrigin
                    )
                )
                .ankiDomainWarpedDissolve(
                    size: geo.size,
                    progress: dissolveProgress,
                    seed: 1.618
                )
                .simultaneousGesture(
                    DragGesture(minimumDistance: 28)
                        .onChanged { value in
                            let dx = value.translation.width
                            let dy = value.translation.height
                            let isHorizontalDominant = abs(dx) > abs(dy) * 1.35

                            // 在 WKWebView 模式下，垂直方向手势完全交给网页原生滚动，绝不劫持
                            guard allowsVerticalRatingSwipe || isHorizontalDominant else {
                                if dragOffset != .zero {
                                    dragOffset = .zero
                                    activeRatingHint = nil
                                }
                                return
                            }

                            if showAnswer {
                                dragOffset = allowsVerticalRatingSwipe
                                    ? value.translation
                                    : CGSize(width: dx, height: dy * 0.18)
                                updateRatingHint()
                            } else {
                                dragOffset = CGSize(
                                    width: dx * 0.45,
                                    height: allowsVerticalRatingSwipe ? dy * 0.45 : 0
                                )
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
                        flipDegrees = 0.0
                        rippleTime = 0.0
                        activeRatingHint = nil
                    }
                }
            }
        }
    }

    private func triggerFlipAnimation(at origin: CGPoint) {
        rippleOrigin = origin
        var snap = Transaction()
        snap.disablesAnimations = true
        withTransaction(snap) {
            // 从 -32° 侧翼切入弹回 0°，保证正反面文字始终正向且绝不发生 180° 水平镜像颠倒
            flipDegrees = -32.0
            rippleTime = 0.02
        }

        HapticSymphony.shared.playFlipRatchet()

        withAnimation(.spring(response: 0.42, dampingFraction: 0.78)) {
            flipDegrees = 0.0
        }
        withAnimation(.easeOut(duration: 0.5)) {
            rippleTime = 1.0
        }

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 520_000_000)
            var reset = Transaction()
            reset.disablesAnimations = true
            withTransaction(reset) {
                rippleTime = 0.0
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
        } else if allowsVerticalRatingSwipe && dragOffset.height > verticalThreshold {
            newHint = .hard
        } else if allowsVerticalRatingSwipe && dragOffset.height < -verticalThreshold {
            newHint = .easy
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
        guard allowsVerticalRatingSwipe || isHorizontalDominant else {
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
            // 左滑 -> Again
            commitRating(.again, exitOffset: CGSize(width: -max(480, cardSize.width * 1.2), height: 0))
        } else if translation.width > horizontalThreshold {
            // 右滑 -> Good
            commitRating(.good, exitOffset: CGSize(width: max(480, cardSize.width * 1.2), height: 0))
        } else if allowsVerticalRatingSwipe && translation.height > verticalThreshold {
            // 下滑 -> Hard
            commitRating(.hard, exitOffset: CGSize(width: translation.width, height: max(650, cardSize.height * 1.2)))
        } else if allowsVerticalRatingSwipe && translation.height < -verticalThreshold {
            // 上抛 -> Easy (触发涡旋解体)
            commitEasyDissolve()
        } else {
            // 未达阈值 -> 弹性归位
            withAnimation(.spring(response: 0.42, dampingFraction: 0.75)) {
                dragOffset = .zero
                activeRatingHint = nil
            }
        }
    }

    private func commitRating(_ rating: Rating, exitOffset: CGSize) {
        withAnimation(.easeIn(duration: 0.20)) {
            dragOffset = exitOffset
        }
        HapticSymphony.shared.playThresholdSnap(for: rating)
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 200_000_000)
            var reset = Transaction()
            reset.disablesAnimations = true
            withTransaction(reset) {
                dragOffset = .zero
                activeRatingHint = nil
                flipDegrees = 0.0
            }
            onRating(rating)
        }
    }

    private func commitEasyDissolve() {
        HapticSymphony.shared.playDissolveBurst()
        withAnimation(.easeOut(duration: 0.42)) {
            dissolveProgress = 1.0
            dragOffset.height -= 48.0
        }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 420_000_000)
            var reset = Transaction()
            reset.disablesAnimations = true
            withTransaction(reset) {
                dissolveProgress = 0.0
                dragOffset = .zero
                activeRatingHint = nil
                flipDegrees = 0.0
            }
            onRating(.easy)
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
