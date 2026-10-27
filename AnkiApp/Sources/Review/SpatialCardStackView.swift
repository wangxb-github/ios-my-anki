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
        let rotY = Double(dragOffset.width) / 16.0
        let rotX = -Double(dragOffset.height) / 22.0

        content
            .offset(dragOffset)
            .rotation3DEffect(.degrees(rotY), axis: (x: 0, y: 1, z: 0), perspective: 0.6)
            .rotation3DEffect(.degrees(rotX), axis: (x: 1, y: 0, z: 0), perspective: 0.6)
            .rotation3DEffect(.degrees(flipDegrees), axis: (x: 0, y: 1, z: 0), perspective: 0.7)
            .ankiCausticRipple(origin: rippleOrigin, time: rippleTime, amplitude: 0.8)
    }
}

/// 具备 3D 物理堆叠、四向阻尼滑动手势与域扭曲斩杀特效的闪卡容器
public struct SpatialCardStackView<Content: View>: View {
    public let showAnswer: Bool
    public let allowsTapToFlip: Bool
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
        onFlip: @escaping () -> Void,
        onRating: @escaping (Rating) -> Void,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.showAnswer = showAnswer
        self.allowsTapToFlip = allowsTapToFlip
        self.onFlip = onFlip
        self.onRating = onRating
        self.content = content
    }

    public var body: some View {
        GeometryReader { geo in
            ZStack {
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

                // 前景主卡片
                ZStack {
                    content()

                    // 滑动方向状态发光提示边缘（仅在已揭晓答案态显示评级色散）
                    if showAnswer, let hint = activeRatingHint {
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
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
                    DragGesture(minimumDistance: 24)
                        .onChanged { value in
                            if showAnswer {
                                dragOffset = value.translation
                                updateRatingHint()
                            } else {
                                // 正面思考态提供阻尼微移反馈，不允许未看答案直接评分
                                dragOffset = CGSize(
                                    width: value.translation.width * 0.45,
                                    height: value.translation.height * 0.45
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
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
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
            // 从 -85° 侧翼切入弹回 0°，保证正反面文字始终正向且绝不发生 180° 水平镜像颠倒
            flipDegrees = -85.0
            rippleTime = 0.02
        }

        HapticSymphony.shared.playFlipRatchet()

        withAnimation(.spring(response: 0.48, dampingFraction: 0.74)) {
            flipDegrees = 0.0
        }
        withAnimation(.easeOut(duration: 0.55)) {
            rippleTime = 1.0
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.56) {
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
        } else if dragOffset.height > verticalThreshold {
            newHint = .hard
        } else if dragOffset.height < -verticalThreshold {
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
        guard showAnswer else {
            // 正面思考态：若滑动超过翻牌阈值则自动揭晓答案，否则弹性归位
            let distance = hypot(translation.width, translation.height)
            withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                dragOffset = .zero
            }
            if distance > flipSwipeThreshold {
                rippleOrigin = CGPoint(x: cardSize.width * 0.5, y: cardSize.height * 0.5)
                onFlip()
            }
            return
        }

        if translation.width < -horizontalThreshold {
            // 左滑 -> Again
            commitRating(.again, exitOffset: CGSize(width: -600, height: translation.height))
        } else if translation.width > horizontalThreshold {
            // 右滑 -> Good
            commitRating(.good, exitOffset: CGSize(width: 600, height: translation.height))
        } else if translation.height > verticalThreshold {
            // 下滑 -> Hard
            commitRating(.hard, exitOffset: CGSize(width: translation.width, height: 750))
        } else if translation.height < -verticalThreshold {
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
        withAnimation(.easeIn(duration: 0.22)) {
            dragOffset = exitOffset
        }
        HapticSymphony.shared.playThresholdSnap(for: rating)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
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
        withAnimation(.easeOut(duration: 0.45)) {
            dissolveProgress = 1.0
            dragOffset.height -= 60.0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
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
