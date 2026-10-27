import SwiftUI

/// 随复习连击与时间动态变换的流体极光背景层
public struct LiquidAuroraBackground: View {
    public var streak: Int = 0
    public var animated: Bool = true

    public init(streak: Int = 0, animated: Bool = true) {
        self.streak = streak
        self.animated = animated
    }

    public var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0, paused: !animated)) { timeline in
            let elapsed = timeline.date.timeIntervalSinceReferenceDate
            let phase = Float(elapsed.truncatingRemainder(dividingBy: 60.0))
            
            let p0 = SIMD2<Float>(0.0, 0.0)
            let p1 = SIMD2<Float>(0.5 + sin(phase * 0.45) * 0.1, cos(phase * 0.3) * 0.05)
            let p2 = SIMD2<Float>(1.0, 0.0)

            let p3 = SIMD2<Float>(sin(phase * 0.35) * 0.08, 0.5 + cos(phase * 0.5) * 0.08)
            let p4 = SIMD2<Float>(0.5 + cos(phase * 0.4) * 0.12, 0.5 + sin(phase * 0.55) * 0.12)
            let p5 = SIMD2<Float>(1.0 + sin(phase * 0.25) * 0.08, 0.5 + cos(phase * 0.45) * 0.08)

            let p6 = SIMD2<Float>(0.0, 1.0)
            let p7 = SIMD2<Float>(0.5 + sin(phase * 0.5) * 0.08, 1.0 + cos(phase * 0.35) * 0.05)
            let p8 = SIMD2<Float>(1.0, 1.0)

            // 根据连击数动态注入高能量极光色彩
            let intensity = min(1.0, Double(streak) / 25.0)
            let cTop = Color.amgiAccent.opacity(0.45 + intensity * 0.2)
            let cMid = Color.purple.opacity(0.35 + intensity * 0.3)
            let cHighlight = Color.cyan.opacity(0.4 + intensity * 0.25)
            let cBase = Color.black.opacity(0.85)

            MeshGradient(
                width: 3,
                height: 3,
                points: [
                    p0, p1, p2,
                    p3, p4, p5,
                    p6, p7, p8
                ],
                colors: [
                    cTop, cHighlight, cMid,
                    cMid, cHighlight, cTop,
                    cBase, cBase, cBase
                ]
            )
            .ignoresSafeArea()
            .overlay(
                Rectangle()
                    .fill(Color.amgiBackground.opacity(0.4))
                    .ignoresSafeArea()
            )
        }
    }
}
